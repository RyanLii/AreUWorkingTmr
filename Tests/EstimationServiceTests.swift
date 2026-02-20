import XCTest
import CoreLocation

#if canImport(SaferNightCore)
@testable import SaferNightCore
#endif

final class EstimationServiceTests: XCTestCase {
    private let service = DefaultEstimationService()

    private func makeProfile(
        region: RegionStandard = .au10g
    ) -> UserProfile {
        UserProfile(
            unitPreference: .metric,
            regionStandard: region,
            workingTomorrow: false
        )
    }

    private func makeOneStandardBeer(at timestamp: Date, region: RegionStandard = .us14g) -> DrinkEntry {
        service.makeEntry(
            category: .beer,
            servingName: "Can",
            volumeMl: 355,
            abvPercent: 5,
            source: .quick,
            timestamp: timestamp,
            locationSnapshot: nil,
            region: region
        )
    }

    func testModelConfigDefaultsMatchSpecV14() {
        let config = DrinkingModelConfig.v14
        XCTAssertEqual(config.defaultDrinkDurationMinutes, 30, accuracy: 0.0001)
        XCTAssertEqual(config.metabolismRateSDPerHour, 0.8, accuracy: 0.0001)
        XCTAssertEqual(config.absorptionLagMinutes, 15, accuracy: 0.0001)
        XCTAssertEqual(config.minAbsorptionDurationMinutes, 20, accuracy: 0.0001)
        XCTAssertEqual(config.burstMergeWindowMinutes, 2, accuracy: 0.0001)
        XCTAssertEqual(config.hydrationBaseMl, 600, accuracy: 0.0001)
        XCTAssertEqual(config.hydrationPerStandardDrinkMl, 250, accuracy: 0.0001)
        XCTAssertEqual(config.hydrationWorkingTomorrowBoostMl, 250, accuracy: 0.0001)
        XCTAssertEqual(config.hydrationMinMl, 300, accuracy: 0.0001)
        XCTAssertEqual(config.hydrationMaxMl, 3000, accuracy: 0.0001)
    }

    func testCustomConfigCanBeInjectedWithoutTouchingAlgorithmCode() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let tuned = DrinkingModelConfig(
            defaultDrinkDurationMinutes: 30,
            metabolismRateSDPerHour: 0.0,
            absorptionLagMinutes: 0,
            minAbsorptionDurationMinutes: 20,
            burstMergeWindowMinutes: 2,
            projectionStepSeconds: 60,
            minProjectionHours: 2,
            maxProjectionHours: 48,
            projectionTailHours: 1,
            hydrationBaseMl: 600,
            hydrationPerStandardDrinkMl: 250,
            hydrationWorkingTomorrowBoostMl: 250,
            hydrationMinMl: 300,
            hydrationMaxMl: 3000
        )
        let tunedService = DefaultEstimationService(config: tuned)
        let entry = tunedService.makeEntry(
            category: .beer,
            servingName: "Can",
            volumeMl: 355,
            abvPercent: 5,
            source: .quick,
            timestamp: now.addingTimeInterval(-10 * 60),
            locationSnapshot: nil,
            region: .us14g
        )

        let snapshot = tunedService.recalculate(entries: [entry], profile: makeProfile(region: .us14g), now: now)

        XCTAssertEqual(snapshot.state, .absorbing)
        XCTAssertGreaterThan(snapshot.effectiveStandardDrinks, 0)
    }

    func testEthanolAndStandardDrinkCalculationUS() {
        let entry = makeOneStandardBeer(at: .now, region: .us14g)
        XCTAssertEqual(entry.ethanolGrams, 14.0, accuracy: 0.2)
        XCTAssertEqual(entry.standardDrinks, 1.0, accuracy: 0.05)
    }

    func testLagSingleDrinkIsPreAbsorption() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = makeOneStandardBeer(at: now.addingTimeInterval(-10 * 60), region: .us14g)

        let snapshot = service.recalculate(entries: [entry], profile: makeProfile(region: .us14g), now: now)

        XCTAssertEqual(snapshot.state, .preAbsorption)
        XCTAssertEqual(snapshot.absorbedStandardDrinks, 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.effectiveStandardDrinks, 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.pendingAbsorptionStandardDrinks, entry.standardDrinks, accuracy: 0.0001)
        XCTAssertGreaterThan(snapshot.projectedZeroTime, now)
    }

    func testAfterLagBodyEntersAbsorbingState() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = makeOneStandardBeer(at: now.addingTimeInterval(-20 * 60), region: .us14g)

        let snapshot = service.recalculate(entries: [entry], profile: makeProfile(region: .us14g), now: now)

        let expectedAbsorbed = entry.standardDrinks * (5.0 / 30.0)
        let inRate = entry.standardDrinks / 0.5
        let expectedStock = max(0, (inRate - 0.8) * (5.0 / 60.0))
        let expectedMetabolized = max(0, expectedAbsorbed - expectedStock)

        XCTAssertEqual(snapshot.state, .absorbing)
        XCTAssertEqual(snapshot.absorbedStandardDrinks, expectedAbsorbed, accuracy: 0.0001)
        XCTAssertEqual(snapshot.effectiveStandardDrinks, expectedStock, accuracy: 0.0001)
        XCTAssertEqual(snapshot.metabolizedStandardDrinks, expectedMetabolized, accuracy: 0.0001)
        XCTAssertGreaterThan(snapshot.pendingAbsorptionStandardDrinks, 0)
    }

    func testAbsorptionFinishedTransitionsToClearing() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = makeOneStandardBeer(at: now.addingTimeInterval(-50 * 60), region: .us14g)

        let snapshot = service.recalculate(entries: [entry], profile: makeProfile(region: .us14g), now: now)

        XCTAssertEqual(snapshot.state, .clearing)
        XCTAssertGreaterThan(snapshot.effectiveStandardDrinks, 0)
        XCTAssertEqual(snapshot.pendingAbsorptionStandardDrinks, 0, accuracy: 0.0001)
    }

    func testTwoDrinksThenFiveHoursThenOneDoesNotUseNegativeDebt() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = [
            makeOneStandardBeer(at: now.addingTimeInterval(-6 * 3600), region: .us14g),
            makeOneStandardBeer(at: now.addingTimeInterval(-5 * 3600 - 50 * 60), region: .us14g),
            makeOneStandardBeer(at: now, region: .us14g)
        ]

        let snapshot = service.recalculate(entries: entries, profile: makeProfile(region: .us14g), now: now)

        XCTAssertEqual(snapshot.state, .preAbsorption)
        XCTAssertEqual(snapshot.effectiveStandardDrinks, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(snapshot.pendingAbsorptionStandardDrinks, 0.9)
    }

    func testOneMinuteFiveDrinksBurstStartsFromPreAbsorption() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let offsets: [TimeInterval] = [0, 10, 20, 30, 50].map { -$0 }
        let entries = offsets.map { makeOneStandardBeer(at: now.addingTimeInterval($0), region: .us14g) }

        let snapshot = service.recalculate(entries: entries, profile: makeProfile(region: .us14g), now: now)

        XCTAssertEqual(snapshot.state, .preAbsorption)
        XCTAssertEqual(snapshot.effectiveStandardDrinks, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(snapshot.pendingAbsorptionStandardDrinks, 4.5)
        XCTAssertGreaterThan(snapshot.estimatedPeakStandardDrinks, 0)
        XCTAssertGreaterThan(snapshot.estimatedPeakTime, now)
    }

    func testTimeToClearUsesFinalClearDefinitionNotTouchZeroInstant() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = makeOneStandardBeer(at: now, region: .us14g)

        let snapshot = service.recalculate(entries: [entry], profile: makeProfile(region: .us14g), now: now)

        XCTAssertGreaterThan(snapshot.remainingToZero, 15 * 60)
        XCTAssertGreaterThan(snapshot.projectedZeroTime, now.addingTimeInterval(15 * 60))
    }

    func testMoreDrinksPushProjectedZeroLater() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let first = service.makeEntry(
            category: .beer,
            servingName: "Schooner",
            volumeMl: 425,
            abvPercent: 4.8,
            source: .quick,
            timestamp: now.addingTimeInterval(-40 * 60),
            locationSnapshot: nil,
            region: .au10g
        )

        let second = service.makeEntry(
            category: .beer,
            servingName: "Schooner",
            volumeMl: 425,
            abvPercent: 4.8,
            source: .quick,
            timestamp: now.addingTimeInterval(-5 * 60),
            locationSnapshot: nil,
            region: .au10g
        )

        let oneDrink = service.recalculate(entries: [first], profile: makeProfile(), now: now)
        let twoDrinks = service.recalculate(entries: [first, second], profile: makeProfile(), now: now)

        XCTAssertGreaterThanOrEqual(twoDrinks.projectedZeroTime, oneDrink.projectedZeroTime)
        XCTAssertGreaterThanOrEqual(twoDrinks.remainingToZero, oneDrink.remainingToZero)
        XCTAssertGreaterThanOrEqual(twoDrinks.effectiveStandardDrinks, oneDrink.effectiveStandardDrinks)
    }

    func testEffectiveLoadDoesNotDependOnWorkingTomorrowToggle() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = [
            service.makeEntry(
                category: .wine,
                servingName: "Standard",
                volumeMl: 150,
                abvPercent: 12.5,
                source: .quick,
                timestamp: now.addingTimeInterval(-25 * 60),
                locationSnapshot: nil,
                region: .au10g
            ),
            service.makeEntry(
                category: .shot,
                servingName: "Classic",
                volumeMl: 45,
                abvPercent: 40,
                source: .quick,
                timestamp: now.addingTimeInterval(-8 * 60),
                locationSnapshot: nil,
                region: .au10g
            )
        ]

        let standard = makeProfile()
        let workingTomorrow = UserProfile(
            unitPreference: .metric,
            regionStandard: .au10g,
            workingTomorrow: true
        )

        let left = service.recalculate(entries: entries, profile: standard, now: now)
        let right = service.recalculate(entries: entries, profile: workingTomorrow, now: now)

        XCTAssertEqual(left.effectiveStandardDrinks, right.effectiveStandardDrinks, accuracy: 0.0001)
        XCTAssertEqual(left.absorbedStandardDrinks, right.absorbedStandardDrinks, accuracy: 0.0001)
        XCTAssertEqual(left.metabolizedStandardDrinks, right.metabolizedStandardDrinks, accuracy: 0.0001)
        XCTAssertEqual(left.projectedZeroTime.timeIntervalSince1970, right.projectedZeroTime.timeIntervalSince1970, accuracy: 0.0001)
    }

    func testHydrationPlanIsBoundedBetweenFloorAndCeiling() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let baseline = service.recalculate(entries: [], profile: makeProfile(), now: now)
        XCTAssertEqual(baseline.hydrationPlanMl, 600)

        let heavyEntries = (0..<20).map { i in
            service.makeEntry(
                category: .beer,
                servingName: "Pint",
                volumeMl: 500,
                abvPercent: 8,
                source: .quick,
                timestamp: now.addingTimeInterval(TimeInterval(-i * 600)),
                locationSnapshot: nil,
                region: .us14g
            )
        }

        let heavy = service.recalculate(entries: heavyEntries, profile: makeProfile(), now: now)
        XCTAssertLessThanOrEqual(heavy.hydrationPlanMl, 3000)
    }

    func testDefaultRegionUsesLocaleMapping() {
        XCTAssertEqual(RegionStandard.defaultForCurrentLocale(locale: Locale(identifier: "en_AU")), .au10g)
        XCTAssertEqual(RegionStandard.defaultForCurrentLocale(locale: Locale(identifier: "en_NZ")), .au10g)
        XCTAssertEqual(RegionStandard.defaultForCurrentLocale(locale: Locale(identifier: "en_GB")), .uk8g)
        XCTAssertEqual(RegionStandard.defaultForCurrentLocale(locale: Locale(identifier: "en_US")), .us14g)
        XCTAssertEqual(RegionStandard.defaultForCurrentLocale(locale: Locale(identifier: "fr_FR")), .au10g)
    }

#if !SWIFT_PACKAGE
    @MainActor
    func testProjectedSnapshotIncludesPendingDrinkSelection() {
        let store = AppStore()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let preset = DrinkPreset(name: "Schooner", category: .beer, defaultVolumeMl: 425, defaultABV: 5)

        let preview = store.projectedSnapshot(adding: preset, count: 2, now: now)

        XCTAssertGreaterThan(preview.totalStandardDrinks, 0)
        XCTAssertGreaterThanOrEqual(preview.effectiveStandardDrinks, 0)
        XCTAssertGreaterThanOrEqual(preview.projectedZeroTime, now)
        XCTAssertGreaterThanOrEqual(preview.remainingToZero, 0)
    }

    @MainActor
    func testQuickDrinkStoresLocationSnapshotWhenProvided() {
        let store = AppStore()
        let preset = DrinkPreset(name: "Beer", category: .beer, defaultVolumeMl: 355, defaultABV: 5)
        let coordinate = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)

        store.addQuickDrink(preset: preset, location: coordinate)

        guard let lastLocation = store.entries.last?.locationSnapshot else {
            return XCTFail("Expected location snapshot to be recorded")
        }
        XCTAssertEqual(lastLocation.latitude, coordinate.latitude, accuracy: 0.000001)
        XCTAssertEqual(lastLocation.longitude, coordinate.longitude, accuracy: 0.000001)
    }

    @MainActor
    func testQuickDrinkLeavesLocationSnapshotNilWhenUnavailable() {
        let store = AppStore()
        let preset = DrinkPreset(name: "Beer", category: .beer, defaultVolumeMl: 355, defaultABV: 5)

        store.addQuickDrink(preset: preset, location: nil)

        XCTAssertNil(store.entries.last?.locationSnapshot)
    }
#endif
}
