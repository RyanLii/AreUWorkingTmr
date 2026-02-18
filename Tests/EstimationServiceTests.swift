import XCTest
import CoreLocation

#if canImport(SaferNightCore)
@testable import SaferNightCore
#endif

final class EstimationServiceTests: XCTestCase {
    private let service = DefaultEstimationService()

    func testEthanolAndStandardDrinkCalculation_US() {
        let entry = service.makeEntry(
            category: .beer,
            servingName: "Can",
            volumeMl: 355,
            abvPercent: 5,
            source: .quick,
            timestamp: .now,
            locationSnapshot: nil,
            region: .us14g
        )

        XCTAssertEqual(entry.ethanolGrams, 14.0, accuracy: 0.2)
        XCTAssertEqual(entry.standardDrinks, 1.0, accuracy: 0.05)
    }

    func testSaferDriveETAUsesLegalLimit() {
        let now = Date()
        let firstDrink = now.addingTimeInterval(-30 * 60)

        let one = service.makeEntry(
            category: .shot,
            servingName: "Classic",
            volumeMl: 44,
            abvPercent: 40,
            source: .quick,
            timestamp: firstDrink,
            locationSnapshot: nil,
            region: .us14g
        )
        let two = service.makeEntry(
            category: .shot,
            servingName: "Classic",
            volumeMl: 44,
            abvPercent: 40,
            source: .quick,
            timestamp: firstDrink.addingTimeInterval(60),
            locationSnapshot: nil,
            region: .us14g
        )

        let profile = UserProfile(
            weightKg: 60,
            biologicalSex: .female,
            unitPreference: .metric,
            regionStandard: .us14g,
            homeLocation: nil
        )

        let snapshot = service.recalculate(entries: [one, two], profile: profile, now: now)

        XCTAssertGreaterThan(snapshot.estimatedBAC, 0.03)
        XCTAssertGreaterThan(snapshot.remainingToSaferDrive, 0)
        XCTAssertGreaterThan(snapshot.saferDriveTime, now)
        XCTAssertNotEqual(snapshot.intoxicationState, .clear)
    }

    func testAULegalLimitIsStricterThanUSForSameSession() {
        let now = Date()
        let entries = [
            service.makeEntry(
                category: .shot,
                servingName: "Classic",
                volumeMl: 44,
                abvPercent: 40,
                source: .quick,
                timestamp: now.addingTimeInterval(-20 * 60),
                locationSnapshot: nil,
                region: .au10g
            ),
            service.makeEntry(
                category: .shot,
                servingName: "Classic",
                volumeMl: 44,
                abvPercent: 40,
                source: .quick,
                timestamp: now.addingTimeInterval(-10 * 60),
                locationSnapshot: nil,
                region: .au10g
            )
        ]

        let auProfile = UserProfile(
            weightKg: 75,
            biologicalSex: .male,
            unitPreference: .metric,
            regionStandard: .au10g,
            homeLocation: nil
        )

        let usProfile = UserProfile(
            weightKg: 75,
            biologicalSex: .male,
            unitPreference: .metric,
            regionStandard: .us14g,
            homeLocation: nil
        )

        let auSnapshot = service.recalculate(entries: entries, profile: auProfile, now: now)
        let usSnapshot = service.recalculate(entries: entries, profile: usProfile, now: now)

        XCTAssertGreaterThanOrEqual(auSnapshot.saferDriveTime, usSnapshot.saferDriveTime)
        XCTAssertGreaterThanOrEqual(auSnapshot.remainingToSaferDrive, usSnapshot.remainingToSaferDrive)
    }

    func testNewDrinkStillRequiresWaitingDueToAbsorption() {
        let now = Date()

        let freshBeer = service.makeEntry(
            category: .beer,
            servingName: "Can",
            volumeMl: 355,
            abvPercent: 5,
            source: .quick,
            timestamp: now,
            locationSnapshot: nil,
            region: .us14g
        )

        let profile = UserProfile(
            weightKg: 75,
            biologicalSex: .male,
            unitPreference: .metric,
            regionStandard: .us14g,
            homeLocation: nil
        )

        let snapshot = service.recalculate(entries: [freshBeer], profile: profile, now: now)

        XCTAssertGreaterThan(snapshot.saferDriveTime, now)
        XCTAssertGreaterThan(snapshot.remainingToSaferDrive, 0)
    }

    func testAlreadySafeStateKeepsLegalBuffer() {
        let now = Date()

        let oldSmallDrink = service.makeEntry(
            category: .beer,
            servingName: "Can",
            volumeMl: 180,
            abvPercent: 4,
            source: .quick,
            timestamp: now.addingTimeInterval(-4 * 3600),
            locationSnapshot: nil,
            region: .us14g
        )

        let profile = UserProfile(
            weightKg: 80,
            biologicalSex: .male,
            unitPreference: .metric,
            regionStandard: .us14g,
            homeLocation: nil
        )

        let snapshot = service.recalculate(entries: [oldSmallDrink], profile: profile, now: now)

        XCTAssertLessThanOrEqual(snapshot.estimatedBAC, profile.regionStandard.legalDriveBACLimit)
        XCTAssertGreaterThanOrEqual(snapshot.remainingToSaferDrive, 4 * 60)
        XCTAssertEqual(snapshot.intoxicationState, .clear)
    }

    func testHydrationPlanIsBounded() {
        let profile = UserProfile(
            weightKg: 120,
            biologicalSex: .male,
            unitPreference: .metric,
            regionStandard: .us14g,
            homeLocation: nil
        )

        let heavyEntries = (0..<20).map { i in
            service.makeEntry(
                category: .beer,
                servingName: "Pint",
                volumeMl: 500,
                abvPercent: 8,
                source: .quick,
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 600)),
                locationSnapshot: nil,
                region: .us14g
            )
        }

        let snapshot = service.recalculate(entries: heavyEntries, profile: profile, now: .now)
        XCTAssertLessThanOrEqual(snapshot.hydrationPlanMl, 3000)
    }

    func testHighIntakeShowsHighRiskState() {
        let now = Date()
        let entries = (0..<6).map { i in
            service.makeEntry(
                category: .shot,
                servingName: "Classic",
                volumeMl: 44,
                abvPercent: 40,
                source: .quick,
                timestamp: now.addingTimeInterval(TimeInterval(-i * 180)),
                locationSnapshot: nil,
                region: .us14g
            )
        }

        let profile = UserProfile(
            weightKg: 55,
            biologicalSex: .female,
            unitPreference: .metric,
            regionStandard: .us14g,
            homeLocation: nil
        )

        let snapshot = service.recalculate(entries: entries, profile: profile, now: now)
        XCTAssertGreaterThan(snapshot.estimatedBAC, 0.015)
        XCTAssertNotEqual(snapshot.intoxicationState, .clear)
    }

    func testInstantBackToBackShotsAreNotFlat() {
        let now = Date()
        let entries = (0..<5).map { _ in
            service.makeEntry(
                category: .shot,
                servingName: "Classic",
                volumeMl: 44,
                abvPercent: 40,
                source: .quick,
                timestamp: now,
                locationSnapshot: nil,
                region: .us14g
            )
        }

        let profile = UserProfile(
            weightKg: 55,
            biologicalSex: .female,
            unitPreference: .metric,
            regionStandard: .us14g,
            homeLocation: nil
        )

        let snapshot = service.recalculate(entries: entries, profile: profile, now: now)
        XCTAssertGreaterThan(snapshot.estimatedBAC, 0.02)
        XCTAssertNotEqual(snapshot.intoxicationState, .light)
        XCTAssertNotEqual(snapshot.intoxicationState, .clear)
    }

    func testRapidShotsDoNotStayInLightState() {
        let now = Date()
        let entries = (0..<6).map { i in
            service.makeEntry(
                category: .shot,
                servingName: "Classic",
                volumeMl: 44,
                abvPercent: 40,
                source: .quick,
                timestamp: now.addingTimeInterval(TimeInterval(-i * 180)),
                locationSnapshot: nil,
                region: .us14g
            )
        }

        let profile = UserProfile(
            weightKg: 55,
            biologicalSex: .female,
            unitPreference: .metric,
            regionStandard: .us14g,
            homeLocation: nil
        )

        let snapshot = service.recalculate(entries: entries, profile: profile, now: now)
        XCTAssertGreaterThanOrEqual(snapshot.estimatedBAC, 0.03)
        XCTAssertNotEqual(snapshot.intoxicationState, .light)
        XCTAssertNotEqual(snapshot.intoxicationState, .clear)
    }

    func testRapidAUSchoonersDoNotStayInLightState() {
        let now = Date()
        let entries = (0..<5).map { _ in
            service.makeEntry(
                category: .beer,
                servingName: "Schooner",
                volumeMl: 425,
                abvPercent: 4.8,
                source: .quick,
                timestamp: now,
                locationSnapshot: nil,
                region: .au10g
            )
        }

        let profile = UserProfile(
            weightKg: 70,
            biologicalSex: .other,
            unitPreference: .metric,
            regionStandard: .au10g,
            homeLocation: nil
        )

        let snapshot = service.recalculate(entries: entries, profile: profile, now: now)
        XCTAssertLessThan(snapshot.estimatedBAC, 0.03)
        XCTAssertNotEqual(snapshot.intoxicationState, .light)
        XCTAssertNotEqual(snapshot.intoxicationState, .clear)
    }

    func testHeavierWeightLowersBACForSameSession() {
        let now = Date()
        let entries = (0..<3).map { i in
            service.makeEntry(
                category: .beer,
                servingName: "Schooner",
                volumeMl: 425,
                abvPercent: 4.8,
                source: .quick,
                timestamp: now.addingTimeInterval(TimeInterval(-i * 12 * 60)),
                locationSnapshot: nil,
                region: .au10g
            )
        }

        let lightProfile = UserProfile(
            weightKg: 55,
            biologicalSex: .other,
            unitPreference: .metric,
            regionStandard: .au10g,
            homeLocation: nil
        )
        let heavyProfile = UserProfile(
            weightKg: 95,
            biologicalSex: .other,
            unitPreference: .metric,
            regionStandard: .au10g,
            homeLocation: nil
        )

        let lightSnapshot = service.recalculate(entries: entries, profile: lightProfile, now: now)
        let heavySnapshot = service.recalculate(entries: entries, profile: heavyProfile, now: now)

        XCTAssertLessThan(heavySnapshot.estimatedBAC, lightSnapshot.estimatedBAC)
        XCTAssertLessThanOrEqual(heavySnapshot.remainingToSaferDrive, lightSnapshot.remainingToSaferDrive)
    }

    func testFemaleProfileHigherBACThanMaleForSameSession() {
        let now = Date()
        let entries = (0..<3).map { i in
            service.makeEntry(
                category: .shot,
                servingName: "Classic",
                volumeMl: 44,
                abvPercent: 40,
                source: .quick,
                timestamp: now.addingTimeInterval(TimeInterval(-i * 7 * 60)),
                locationSnapshot: nil,
                region: .au10g
            )
        }

        let maleProfile = UserProfile(
            weightKg: 70,
            biologicalSex: .male,
            unitPreference: .metric,
            regionStandard: .au10g,
            homeLocation: nil
        )
        let femaleProfile = UserProfile(
            weightKg: 70,
            biologicalSex: .female,
            unitPreference: .metric,
            regionStandard: .au10g,
            homeLocation: nil
        )

        let maleSnapshot = service.recalculate(entries: entries, profile: maleProfile, now: now)
        let femaleSnapshot = service.recalculate(entries: entries, profile: femaleProfile, now: now)

        XCTAssertGreaterThan(femaleSnapshot.estimatedBAC, maleSnapshot.estimatedBAC)
        XCTAssertGreaterThanOrEqual(femaleSnapshot.remainingToSaferDrive, maleSnapshot.remainingToSaferDrive)
    }

    func testBACDecreasesAfterSixHoursWithoutNewDrinks() {
        let now = Date()
        let entries = (0..<4).map { i in
            service.makeEntry(
                category: .wine,
                servingName: "Standard",
                volumeMl: 150,
                abvPercent: 12.5,
                source: .quick,
                timestamp: now.addingTimeInterval(TimeInterval(-i * 20 * 60)),
                locationSnapshot: nil,
                region: .au10g
            )
        }

        let profile = UserProfile(
            weightKg: 70,
            biologicalSex: .other,
            unitPreference: .metric,
            regionStandard: .au10g,
            homeLocation: nil
        )

        let currentSnapshot = service.recalculate(entries: entries, profile: profile, now: now)
        let muchLaterSnapshot = service.recalculate(
            entries: entries,
            profile: profile,
            now: now.addingTimeInterval(6 * 3600)
        )

        XCTAssertLessThan(muchLaterSnapshot.estimatedBAC, currentSnapshot.estimatedBAC)
        XCTAssertLessThanOrEqual(muchLaterSnapshot.remainingToSaferDrive, currentSnapshot.remainingToSaferDrive)
    }

    func testExtraDrinkCannotImproveSaferDriveETA() {
        let now = Date()

        let first = service.makeEntry(
            category: .beer,
            servingName: "Schooner",
            volumeMl: 425,
            abvPercent: 4.8,
            source: .quick,
            timestamp: now.addingTimeInterval(-12 * 60),
            locationSnapshot: nil,
            region: .au10g
        )

        let second = service.makeEntry(
            category: .beer,
            servingName: "Schooner",
            volumeMl: 425,
            abvPercent: 4.8,
            source: .quick,
            timestamp: now,
            locationSnapshot: nil,
            region: .au10g
        )

        let profile = UserProfile(
            weightKg: 72,
            biologicalSex: .male,
            unitPreference: .metric,
            regionStandard: .au10g,
            homeLocation: nil
        )

        let oneDrinkSnapshot = service.recalculate(entries: [first], profile: profile, now: now)
        let twoDrinkSnapshot = service.recalculate(entries: [first, second], profile: profile, now: now)

        XCTAssertGreaterThanOrEqual(twoDrinkSnapshot.remainingToSaferDrive, oneDrinkSnapshot.remainingToSaferDrive)
        XCTAssertGreaterThanOrEqual(twoDrinkSnapshot.saferDriveTime, oneDrinkSnapshot.saferDriveTime)
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
        let now = Date()
        let preset = DrinkPreset(name: "Schooner", category: .beer, defaultVolumeMl: 425, defaultABV: 5)

        let preview = store.projectedSnapshot(adding: preset, count: 2, now: now)

        XCTAssertGreaterThan(preview.totalStandardDrinks, 0)
        XCTAssertGreaterThan(preview.saferDriveTime, now)
        XCTAssertGreaterThan(preview.remainingToSaferDrive, 0)
    }

    @MainActor
    func testProjectedSnapshotGetsMoreConservativeWhenWorkingTomorrowOn() {
        let store = AppStore()
        let seedPreset = DrinkPreset(name: "Beer", category: .beer, defaultVolumeMl: 355, defaultABV: 5)
        let extraPreset = DrinkPreset(name: "Shot", category: .shot, defaultVolumeMl: 44, defaultABV: 40)

        store.addQuickDrink(preset: seedPreset)
        let now = Date()

        store.setWorkingTomorrowForCurrentSession(false)
        let offSnapshot = store.projectedSnapshot(adding: extraPreset, count: 1, now: now)

        store.setWorkingTomorrowForCurrentSession(true)
        let onSnapshot = store.projectedSnapshot(adding: extraPreset, count: 1, now: now)

        XCTAssertGreaterThanOrEqual(onSnapshot.saferDriveTime, offSnapshot.saferDriveTime)
        XCTAssertGreaterThanOrEqual(onSnapshot.remainingToSaferDrive, offSnapshot.remainingToSaferDrive)
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

    @MainActor
    func testHealthProfileUpdateFallsBackWhenDataMissing() {
        let store = AppStore()
        let initial = store.profile

        store.updateProfileFromHealth(weightKg: nil, biologicalSex: nil)

        XCTAssertEqual(store.profile.weightKg, initial.weightKg, accuracy: 0.001)
        XCTAssertEqual(store.profile.biologicalSex, initial.biologicalSex)
    }

    @MainActor
    func testHealthProfileUpdateAppliesAndClampsWeight() {
        let store = AppStore()

        store.updateProfileFromHealth(weightKg: 500, biologicalSex: .female)

        XCTAssertEqual(store.profile.weightKg, 220, accuracy: 0.001)
        XCTAssertEqual(store.profile.biologicalSex, .female)
    }
#endif
}
