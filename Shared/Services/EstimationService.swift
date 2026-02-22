import Foundation

protocol EstimationService {
    func makeEntry(
        category: DrinkCategory,
        servingName: String?,
        volumeMl: Double,
        abvPercent: Double,
        source: DrinkSource,
        timestamp: Date,
        locationSnapshot: LocationSnapshot?,
        region: RegionStandard
    ) -> DrinkEntry

    func recalculate(entries: [DrinkEntry], profile: UserProfile, now: Date) -> SessionSnapshot
}

// Single-source tuning block for drinking model behavior.
// Keep values aligned with drinking_model_algorithm/MODEL_SPEC_EN.md.
struct DrinkingModelConfig: Equatable {
    var defaultDrinkDurationMinutes: Double
    var metabolismRateSDPerHour: Double
    var absorptionLagMinutes: Double
    var minAbsorptionDurationMinutes: Double
    var burstMergeWindowMinutes: Double

    // Projection/search controls for final clear time.
    var projectionStepSeconds: TimeInterval
    var minProjectionHours: Double
    var maxProjectionHours: Double
    var projectionTailHours: Double

    // Hydration guidance controls.
    var hydrationBaseMl: Double
    var hydrationPerStandardDrinkMl: Double
    var hydrationWorkingTomorrowBoostMl: Double
    var hydrationMinMl: Double
    var hydrationMaxMl: Double

    static let v14 = DrinkingModelConfig(
        defaultDrinkDurationMinutes: 30,
        metabolismRateSDPerHour: 0.8,
        absorptionLagMinutes: 15,
        minAbsorptionDurationMinutes: 20,
        burstMergeWindowMinutes: 2,
        projectionStepSeconds: 60,
        minProjectionHours: 6,
        maxProjectionHours: 72,
        projectionTailHours: 2,
        hydrationBaseMl: 600,
        hydrationPerStandardDrinkMl: 250,
        hydrationWorkingTomorrowBoostMl: 250,
        hydrationMinMl: 300,
        hydrationMaxMl: 3000
    )
}

struct DefaultEstimationService: EstimationService {
    private struct IntakeBlock {
        let standardDrinks: Double
        let start: Date
        let end: Date
    }

    private let ethanolDensity = 0.789
    private let config: DrinkingModelConfig

    private let epsilon = 1e-9

    init(config: DrinkingModelConfig = .v14) {
        self.config = config
    }

    func makeEntry(
        category: DrinkCategory,
        servingName: String?,
        volumeMl: Double,
        abvPercent: Double,
        source: DrinkSource,
        timestamp: Date,
        locationSnapshot: LocationSnapshot?,
        region: RegionStandard
    ) -> DrinkEntry {
        let ethanolGrams = max(0, volumeMl) * max(0, abvPercent) / 100 * ethanolDensity
        let standardDrinks = ethanolGrams / region.gramsPerStandardDrink

        return DrinkEntry(
            timestamp: timestamp,
            category: category,
            servingName: servingName,
            volumeMl: volumeMl,
            abvPercent: abvPercent,
            ethanolGrams: ethanolGrams,
            standardDrinks: standardDrinks,
            source: source,
            locationSnapshot: locationSnapshot
        )
    }

    func recalculate(entries: [DrinkEntry], profile: UserProfile, now: Date) -> SessionSnapshot {
        let sortedEntries = entries.sorted(by: { $0.timestamp < $1.timestamp })
        let blocks = buildEffectiveBlocks(entries: sortedEntries)
        let totalStandardDrinks = blocks.reduce(0) { $0 + $1.standardDrinks }
        let hydrationPlanMl = hydrationPlan(
            totalStandardDrinks: totalStandardDrinks,
            workingTomorrow: profile.workingTomorrow
        )

        guard let sessionStart = blocks.map(\.start).min() else {
            return SessionSnapshot(
                date: now,
                totalStandardDrinks: 0,
                state: .cleared,
                effectiveStandardDrinks: 0,
                absorbedStandardDrinks: 0,
                pendingAbsorptionStandardDrinks: 0,
                metabolizedStandardDrinks: 0,
                projectedZeroTime: now,
                remainingToZero: 0,
                estimatedPeakStandardDrinks: 0,
                estimatedPeakTime: now,
                lastDrinkTime: nil,
                clearingStartedAt: nil,
                clearingElapsed: 0,
                hydrationPlanMl: hydrationPlanMl,
                recommendElectrolytes: false
            )
        }

        let absorbedNow = absorbedTotal(at: now, blocks: blocks)
        let pendingNow = max(0, totalStandardDrinks - absorbedNow)
        let currentStock = bodyStock(at: now, blocks: blocks)
        let metabolizedNow = max(0, absorbedNow - currentStock)
        let state = bodyLoadState(now: now, currentStock: currentStock, pendingAbsorption: pendingNow, blocks: blocks)
        let projectedZero = projectedZeroTime(
            now: now,
            currentStock: currentStock,
            blocks: blocks,
            totalStandardDrinks: totalStandardDrinks
        )
        let remainingToZero = max(0, projectedZero.timeIntervalSince(now))
        let peak = estimatedPeak(blocks: blocks, sessionStart: sessionStart, projectionEnd: projectedZero)
        let clearingStartedAt = clearingStartTime(state: state, peakTime: peak.time, now: now)
        let clearingElapsed = max(0, now.timeIntervalSince(clearingStartedAt ?? now))
        let projectedRecovery = recoveryTime(totalStandardDrinks: totalStandardDrinks, projectedZeroTime: projectedZero)

        return SessionSnapshot(
            date: now,
            totalStandardDrinks: totalStandardDrinks,
            state: state,
            effectiveStandardDrinks: currentStock,
            absorbedStandardDrinks: absorbedNow,
            pendingAbsorptionStandardDrinks: pendingNow,
            metabolizedStandardDrinks: metabolizedNow,
            projectedZeroTime: projectedZero,
            remainingToZero: remainingToZero,
            projectedRecoveryTime: projectedRecovery,
            estimatedPeakStandardDrinks: peak.value,
            estimatedPeakTime: peak.time,
            lastDrinkTime: sortedEntries.last?.timestamp,
            clearingStartedAt: clearingStartedAt,
            clearingElapsed: clearingElapsed,
            hydrationPlanMl: hydrationPlanMl,
            recommendElectrolytes: totalStandardDrinks >= 3
        )
    }

    private func buildEffectiveBlocks(entries: [DrinkEntry]) -> [IntakeBlock] {
        let baseBlocks = baseTimingBlocks(entries: entries)
        return mergeBurstBlocks(baseBlocks)
    }

    private func baseTimingBlocks(entries: [DrinkEntry]) -> [IntakeBlock] {
        guard !entries.isEmpty else { return [] }
        let sorted = entries.sorted(by: { $0.timestamp < $1.timestamp })
        var blocks: [IntakeBlock] = []
        blocks.reserveCapacity(sorted.count)

        for (index, entry) in sorted.enumerated() {
            guard entry.standardDrinks > 0 else { continue }

            let start = entry.timestamp
            let defaultEnd = start.addingTimeInterval(config.defaultDrinkDurationMinutes * 60)
            let nextStart = sorted.indices.contains(index + 1) ? sorted[index + 1].timestamp : nil
            let end = max(start, min(defaultEnd, nextStart ?? defaultEnd))

            blocks.append(
                IntakeBlock(
                    standardDrinks: entry.standardDrinks,
                    start: start,
                    end: end
                )
            )
        }

        return blocks
    }

    private func mergeBurstBlocks(_ blocks: [IntakeBlock]) -> [IntakeBlock] {
        guard !blocks.isEmpty else { return [] }
        guard config.burstMergeWindowMinutes > 0 else { return blocks }

        let sorted = blocks.sorted(by: { $0.start < $1.start })
        let threshold = config.burstMergeWindowMinutes * 60
        var merged: [IntakeBlock] = []
        var cluster: [IntakeBlock] = [sorted[0]]

        func flushCluster(_ cluster: [IntakeBlock], into merged: inout [IntakeBlock]) {
            merged.append(
                IntakeBlock(
                    standardDrinks: cluster.reduce(0) { $0 + $1.standardDrinks },
                    start: cluster.map(\.start).min() ?? cluster[0].start,
                    end: cluster.map(\.end).max() ?? cluster[0].end
                )
            )
        }

        for block in sorted.dropFirst() {
            if block.start.timeIntervalSince(cluster.last?.start ?? block.start) <= threshold + epsilon {
                cluster.append(block)
            } else {
                flushCluster(cluster, into: &merged)
                cluster = [block]
            }
        }

        flushCluster(cluster, into: &merged)
        return merged
    }

    private func absorptionWindow(for block: IntakeBlock) -> (start: Date, end: Date, durationHours: Double) {
        let start = block.start.addingTimeInterval(config.absorptionLagMinutes * 60)
        let endBase = block.end.addingTimeInterval(config.absorptionLagMinutes * 60)
        let end = max(endBase, start.addingTimeInterval(config.minAbsorptionDurationMinutes * 60))
        let durationHours = max(epsilon, end.timeIntervalSince(start) / 3600)
        return (start, end, durationHours)
    }

    private func absorbedTotal(at time: Date, blocks: [IntakeBlock]) -> Double {
        guard !blocks.isEmpty else { return 0 }

        var total = 0.0
        for block in blocks {
            let window = absorptionWindow(for: block)
            total += block.standardDrinks * absorptionProportion(at: time, start: window.start, end: window.end)
        }
        return max(0, total)
    }

    private func absorptionProportion(at time: Date, start: Date, end: Date) -> Double {
        if time <= start { return 0 }
        if time >= end { return 1 }

        let duration = end.timeIntervalSince(start)
        guard duration > epsilon else { return 1 }
        return min(max(time.timeIntervalSince(start) / duration, 0), 1)
    }

    private func pendingAbsorption(at time: Date, blocks: [IntakeBlock], totalStandardDrinks: Double) -> Double {
        max(0, totalStandardDrinks - absorbedTotal(at: time, blocks: blocks))
    }

    private func bodyStock(at time: Date, blocks: [IntakeBlock]) -> Double {
        guard let start = blocks.map(\.start).min() else { return 0 }
        guard time > start else { return 0 }
        return advanceBodyStock(
            from: start,
            to: time,
            initialStock: 0,
            blocks: blocks
        )
    }

    private func advanceBodyStock(from start: Date, to end: Date, initialStock: Double, blocks: [IntakeBlock]) -> Double {
        guard end > start else { return max(0, initialStock) }

        var stock = max(0, initialStock)
        let points = segmentBoundaries(from: start, to: end, blocks: blocks)

        for index in 0..<(points.count - 1) {
            let left = points[index]
            let right = points[index + 1]
            let dtHours = max(0, right.timeIntervalSince(left) / 3600)
            guard dtHours > epsilon else { continue }

            let mid = left.addingTimeInterval(right.timeIntervalSince(left) / 2)
            let inRate = absorptionRate(at: mid, blocks: blocks)
            stock = advanceStockSegment(stock: stock, inRate: inRate, dtHours: dtHours)
        }

        return max(0, stock)
    }

    private func segmentBoundaries(from start: Date, to end: Date, blocks: [IntakeBlock]) -> [Date] {
        var points: [Date] = [start, end]

        for block in blocks {
            let window = absorptionWindow(for: block)
            if start < window.start, window.start < end {
                points.append(window.start)
            }
            if start < window.end, window.end < end {
                points.append(window.end)
            }
        }

        let unique = Set(points.map(\.timeIntervalSinceReferenceDate))
        return unique
            .sorted()
            .map(Date.init(timeIntervalSinceReferenceDate:))
    }

    private func absorptionRate(at time: Date, blocks: [IntakeBlock]) -> Double {
        var rate = 0.0

        for block in blocks {
            let window = absorptionWindow(for: block)
            if window.start < time, time < window.end {
                rate += block.standardDrinks / window.durationHours
            }
        }

        return rate
    }

    private func advanceStockSegment(stock: Double, inRate: Double, dtHours: Double) -> Double {
        guard dtHours > epsilon else { return max(0, stock) }

        let current = max(0, stock)
        let net = inRate - config.metabolismRateSDPerHour

        if current <= epsilon {
            return max(0, net) * dtHours
        }

        if net >= 0 {
            return current + net * dtHours
        }

        return max(0, current - (config.metabolismRateSDPerHour - inRate) * dtHours)
    }

    // v2.0: Dynamic recovery time — earlier than full clearance.
    // Buffer scales with session intake so heavier sessions get a larger safety margin.
    private func recoveryTime(totalStandardDrinks: Double, projectedZeroTime: Date) -> Date {
        let bufferRaw = 0.33 + 0.08 * max(0, totalStandardDrinks - 1)
        let bufferHours = min(2.0, max(0.25, bufferRaw))
        return projectedZeroTime.addingTimeInterval(-bufferHours * 3600)
    }

    private func projectedZeroTime(
        now: Date,
        currentStock: Double,
        blocks: [IntakeBlock],
        totalStandardDrinks: Double
    ) -> Date {
        let pendingNow = pendingAbsorption(at: now, blocks: blocks, totalStandardDrinks: totalStandardDrinks)
        if currentStock <= epsilon, pendingNow <= epsilon {
            return now
        }

        let lastAbsorptionEnd = blocks
            .map { absorptionWindow(for: $0).end }
            .max() ?? now

        let loadHorizonHours = max(
            config.minProjectionHours,
            (totalStandardDrinks / config.metabolismRateSDPerHour) + config.projectionTailHours
        )
        let absorptionHorizonHours = max(
            0,
            lastAbsorptionEnd.timeIntervalSince(now) / 3600
        ) + config.projectionTailHours
        let horizonHours = min(config.maxProjectionHours, max(loadHorizonHours, absorptionHorizonHours))
        let projectionEnd = now.addingTimeInterval(horizonHours * 3600)

        var probe = now
        var stock = max(0, currentStock)

        while probe < projectionEnd {
            let candidate = probe.addingTimeInterval(config.projectionStepSeconds)
            let next = min(candidate, projectionEnd)
            stock = advanceBodyStock(from: probe, to: next, initialStock: stock, blocks: blocks)
            probe = next

            let pending = pendingAbsorption(
                at: probe,
                blocks: blocks,
                totalStandardDrinks: totalStandardDrinks
            )
            if stock <= epsilon, pending <= epsilon {
                return probe
            }
        }

        return projectionEnd
    }

    private func estimatedPeak(blocks: [IntakeBlock], sessionStart: Date, projectionEnd: Date) -> (value: Double, time: Date) {
        guard projectionEnd > sessionStart else {
            return (0, sessionStart)
        }

        let points = segmentBoundaries(from: sessionStart, to: projectionEnd, blocks: blocks)
        var stock = 0.0
        var peakValue = 0.0
        var peakTime = sessionStart
        var last = sessionStart

        for point in points where point > last {
            stock = advanceBodyStock(from: last, to: point, initialStock: stock, blocks: blocks)
            if stock > peakValue + epsilon {
                peakValue = stock
                peakTime = point
            }
            last = point
        }

        return (peakValue, peakTime)
    }

    private func bodyLoadState(
        now: Date,
        currentStock: Double,
        pendingAbsorption: Double,
        blocks: [IntakeBlock]
    ) -> BodyLoadState {
        let inRate = absorptionRate(at: now, blocks: blocks)
        let derivative: Double

        if currentStock > epsilon {
            derivative = inRate - config.metabolismRateSDPerHour
        } else {
            derivative = max(0, inRate - config.metabolismRateSDPerHour)
        }

        if currentStock <= epsilon {
            if pendingAbsorption <= epsilon {
                return .cleared
            }
            return derivative > epsilon ? .absorbing : .preAbsorption
        }

        return derivative > epsilon ? .absorbing : .clearing
    }

    private func clearingStartTime(state: BodyLoadState, peakTime: Date, now: Date) -> Date? {
        guard state == .clearing || state == .cleared else { return nil }
        guard peakTime <= now else { return nil }
        return peakTime
    }

    private func hydrationPlan(totalStandardDrinks: Double, workingTomorrow: Bool) -> Int {
        let base = config.hydrationBaseMl
        let perDrink = totalStandardDrinks * config.hydrationPerStandardDrinkMl
        let tomorrowBoost = workingTomorrow ? config.hydrationWorkingTomorrowBoostMl : 0
        let raw = base + perDrink + tomorrowBoost
        let clamped = min(max(raw, config.hydrationMinMl), config.hydrationMaxMl)
        return Int(clamped.rounded())
    }
}
