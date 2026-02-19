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

struct DefaultEstimationService: EstimationService {
    private let ethanolDensity = 0.789

    // Time simulation settings.
    private let etaStepSeconds: TimeInterval = 60
    private let etaHorizonHours = 24.0
    private let minEtaHorizonHours = 6.0
    private let etaSafetyTailHours = 2.0
    private let stateHorizonHours = 2.0

    // Small buffer after estimate, still an estimate not a legal guarantee.
    private let defaultLegalDriveBufferSeconds: TimeInterval = 5 * 60
    private let workingTomorrowLegalDriveBufferSeconds: TimeInterval = 10 * 60

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
        let sorted = entries.sorted(by: { $0.timestamp < $1.timestamp })
        let totalEthanolGrams = sorted.reduce(0) { $0 + $1.ethanolGrams }
        let totalStandardDrinks = totalEthanolGrams / profile.regionStandard.gramsPerStandardDrink

        let legalThreshold = profile.regionStandard.legalDriveBACLimit
        let legalBuffer = legalDriveBuffer(for: profile)

        let simulationHorizonHours = simulationHorizonHours(entries: sorted, profile: profile, now: now)
        let samples = bacSamples(
            entries: sorted,
            profile: profile,
            from: now,
            horizonHours: simulationHorizonHours
        )

        let nowBAC = samples.first?.bac ?? bac(at: now, entries: sorted, profile: profile)
        let nearTermPeakBAC = peakBAC(samples: samples, from: now, horizonHours: stateHorizonHours)
        let stateBAC = max(nowBAC, nearTermPeakBAC)
        let saferDriveTime = estimateDriveReadyTime(
            samples: samples,
            now: now,
            threshold: legalThreshold,
            conservativeBuffer: legalBuffer,
            profile: profile,
            entries: sorted
        )
        let remainingSeconds = max(0, saferDriveTime.timeIntervalSince(now))

        let hydrationPlanMl = hydrationPlan(
            weightKg: profile.weightKg,
            totalStandardDrinks: totalStandardDrinks,
            workingTomorrow: profile.workingTomorrow
        )

        return SessionSnapshot(
            date: now,
            totalStandardDrinks: totalStandardDrinks,
            estimatedBAC: nowBAC,
            intoxicationState: intoxicationState(for: stateBAC),
            saferDriveTime: saferDriveTime,
            remainingToSaferDrive: remainingSeconds,
            hydrationPlanMl: hydrationPlanMl,
            recommendElectrolytes: totalStandardDrinks >= 3
        )
    }

    private func legalDriveBuffer(for profile: UserProfile) -> TimeInterval {
        profile.workingTomorrow ? workingTomorrowLegalDriveBufferSeconds : defaultLegalDriveBufferSeconds
    }

    private func estimateDriveReadyTime(
        samples: [BACSample],
        now: Date,
        threshold: Double,
        conservativeBuffer: TimeInterval,
        profile: UserProfile,
        entries: [DrinkEntry]
    ) -> Date {
        guard !samples.isEmpty else {
            return now
        }

        let maxDate = samples.last?.time ?? now

        var futureMaxBAC = Array(repeating: 0.0, count: samples.count)
        var runningMax = 0.0

        for index in stride(from: samples.count - 1, through: 0, by: -1) {
            runningMax = max(runningMax, samples[index].bac)
            futureMaxBAC[index] = runningMax
        }

        // If we're already below threshold now and the projected near/far future
        // also stays below threshold, don't add extra buffer minutes.
        if let current = samples.first,
           current.bac <= threshold,
           (futureMaxBAC.first ?? 0) <= threshold {
            let settlingBuffer = immediateSafeSettlingBuffer(for: profile, entries: entries, now: now)
            guard settlingBuffer > 0 else { return now }
            return min(maxDate, now.addingTimeInterval(settlingBuffer))
        }

        if let firstStableSafeIndex = samples.indices.first(where: { idx in
            samples[idx].bac <= threshold && futureMaxBAC[idx] <= threshold
        }) {
            let estimate = samples[firstStableSafeIndex].time.addingTimeInterval(conservativeBuffer)
            return min(maxDate, estimate)
        }

        return maxDate
    }

    // In stricter regions, keep a short post-log settling window so
    // "just logged" drinks do not look instantly fully settled.
    private func immediateSafeSettlingBuffer(
        for profile: UserProfile,
        entries: [DrinkEntry],
        now: Date
    ) -> TimeInterval {
        guard let latestEntry = entries.last else { return 0 }
        let timeSinceLastDrink = max(0, now.timeIntervalSince(latestEntry.timestamp))

        // Only apply when the latest drink is recent.
        guard timeSinceLastDrink < 45 * 60 else { return 0 }

        switch profile.regionStandard {
        case .au10g:
            return 20 * 60
        case .uk8g:
            return 10 * 60
        case .us14g:
            return 0
        }
    }

    // Short-horizon peak BAC helps avoid under-reporting state when many drinks are
    // logged in quick succession and absorption is still catching up.
    private func peakBAC(
        samples: [BACSample],
        from now: Date,
        horizonHours: Double
    ) -> Double {
        let end = now.addingTimeInterval(max(0, horizonHours) * 3600)
        return samples
            .lazy
            .filter { $0.time <= end }
            .map(\.bac)
            .max() ?? 0
    }

    private func simulationHorizonHours(entries: [DrinkEntry], profile: UserProfile, now: Date) -> Double {
        guard let earliest = entries.first else {
            return 0
        }

        let bodyDistribution = bodyDistribution(for: profile)
        let metabolismPerHour = metabolismRatePerHour(for: profile) * bodyDistribution / 100
        guard metabolismPerHour > 0 else {
            return etaHorizonHours
        }

        let totalEthanolGrams = entries.reduce(0) { $0 + $1.ethanolGrams }
        let elapsedHours = max(0, now.timeIntervalSince(earliest.timestamp) / 3600)
        let remainingEthanol = max(0, totalEthanolGrams - (metabolismPerHour * elapsedHours))

        let projectedClearanceHours = remainingEthanol / metabolismPerHour
        let targetHorizon = projectedClearanceHours + etaSafetyTailHours
        return min(etaHorizonHours, max(minEtaHorizonHours, targetHorizon))
    }

    private func bacSamples(
        entries: [DrinkEntry],
        profile: UserProfile,
        from now: Date,
        horizonHours: Double
    ) -> [BACSample] {
        let end = now.addingTimeInterval(max(0, horizonHours) * 3600)

        guard !entries.isEmpty else {
            return [BACSample(time: now, bac: 0)]
        }

        var probe = now
        var samples: [BACSample] = []

        while probe <= end {
            let bac = bac(at: probe, entries: entries, profile: profile)
            samples.append(BACSample(time: probe, bac: bac))
            probe = probe.addingTimeInterval(etaStepSeconds)
        }

        if samples.last?.time != end {
            samples.append(BACSample(time: end, bac: bac(at: end, entries: entries, profile: profile)))
        }

        return samples
    }

    private func bac(at time: Date, entries: [DrinkEntry], profile: UserProfile) -> Double {
        guard !entries.isEmpty else {
            return 0
        }

        let bodyDistribution = bodyDistribution(for: profile)
        let metabolismRatePerHour = metabolismRatePerHour(for: profile)
        let metabolismGramsPerHour = metabolismRatePerHour * bodyDistribution / 100

        var totalAbsorbedGrams: Double = 0
        var earliestTimestamp = time

        for entry in entries {
            earliestTimestamp = min(earliestTimestamp, entry.timestamp)

            let elapsedHours = max(0, time.timeIntervalSince(entry.timestamp) / 3600)
            let absorptionWindow = absorptionWindowHours(for: entry)
            let progress = absorptionProgress(
                elapsedHours: elapsedHours,
                absorptionWindowHours: absorptionWindow,
                curvePower: absorptionCurvePower(for: entry)
            )

            // Keep a small immediate uptake so back-to-back logs do not appear flat.
            let fraction = min(max(progress, initialAbsorptionFraction(for: entry)), 1)

            totalAbsorbedGrams += entry.ethanolGrams * fraction
        }

        let elapsedSinceFirstDrinkHours = max(0, time.timeIntervalSince(earliestTimestamp) / 3600)
        let metabolizedGrams = metabolismGramsPerHour * elapsedSinceFirstDrinkHours
        let activeEthanolGrams = max(0, totalAbsorbedGrams - metabolizedGrams)

        let bac = (activeEthanolGrams / bodyDistribution) * 100
        return max(0, bac)
    }

    private func bodyDistribution(for profile: UserProfile) -> Double {
        let weightKg = max(profile.weightKg, 1)
        let heightFactor = min(max(profile.heightCm / 170, 0.85), 1.15)
        return max(profile.biologicalSex.widmarkConstant * weightKg * 1000 * heightFactor, 1)
    }

    private func metabolismRatePerHour(for profile: UserProfile) -> Double {
        switch profile.biologicalSex {
        case .male:
            return 0.016
        case .female:
            return 0.014
        case .other:
            return 0.015
        }
    }

    private func intoxicationState(for bac: Double) -> IntoxicationState {
        switch bac {
        case ..<0.01:
            return .clear
        case ..<0.03:
            return .light
        case ..<0.06:
            return .social
        case ..<0.09:
            return .tipsy
        case ..<0.14:
            return .wavy
        default:
            return .high
        }
    }

    private func initialAbsorptionFraction(for entry: DrinkEntry) -> Double {
        var base: Double

        switch entry.category {
        case .beer: base = 0.10
        case .wine: base = 0.12
        case .shot: base = 0.18
        case .cocktail: base = 0.14
        case .spirits: base = 0.16
        case .custom: base = 0.12
        }

        if entry.abvPercent >= 30 {
            base += 0.03
        }

        if entry.volumeMl >= 500 {
            base -= 0.02
        }

        return min(max(base, 0.08), 0.24)
    }

    private func absorptionWindowHours(for entry: DrinkEntry) -> Double {
        var base: Double

        switch entry.category {
        case .beer: base = 0.95
        case .wine: base = 0.85
        case .shot: base = 0.70
        case .cocktail: base = 0.90
        case .spirits: base = 0.75
        case .custom: base = 0.90
        }

        if entry.volumeMl >= 500 {
            base += 0.25
        } else if entry.volumeMl >= 250 {
            base += 0.12
        }

        if entry.abvPercent >= 30 {
            base += 0.18
        } else if entry.abvPercent <= 5 {
            base -= 0.05
        }

        return min(max(base, 0.5), 1.8)
    }

    private func absorptionCurvePower(for entry: DrinkEntry) -> Double {
        var power: Double

        switch entry.category {
        case .beer: power = 1.18
        case .wine: power = 1.05
        case .shot: power = 0.86
        case .cocktail: power = 1.0
        case .spirits: power = 0.92
        case .custom: power = 1.0
        }

        if entry.abvPercent >= 30 {
            power -= 0.05
        } else if entry.abvPercent <= 5 {
            power += 0.05
        }

        if entry.volumeMl >= 500 {
            power += 0.10
        }

        return min(max(power, 0.75), 1.30)
    }

    private func absorptionProgress(
        elapsedHours: Double,
        absorptionWindowHours: Double,
        curvePower: Double
    ) -> Double {
        guard absorptionWindowHours > 0 else {
            return 1
        }

        let normalized = min(max(elapsedHours / absorptionWindowHours, 0), 1)
        return pow(normalized, curvePower)
    }

    private func hydrationPlan(weightKg: Double, totalStandardDrinks: Double, workingTomorrow: Bool) -> Int {
        let base = weightKg * 8
        let perDrink = totalStandardDrinks * 250
        let tomorrowBoost = workingTomorrow ? 250.0 : 0
        let raw = base + perDrink + tomorrowBoost
        let clamped = min(max(raw, 300), 3000)
        return Int(clamped.rounded())
    }
}

private struct BACSample {
    let time: Date
    let bac: Double
}
