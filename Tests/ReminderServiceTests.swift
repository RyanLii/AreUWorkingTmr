import XCTest

#if canImport(SaferNightCore)
@testable import SaferNightCore
#endif

final class ReminderServiceTests: XCTestCase {
    private let service = DefaultReminderService()

    private func snapshot(total: Double, hydration: Int = 900, electrolytes: Bool = false) -> SessionSnapshot {
        SessionSnapshot(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            totalStandardDrinks: total,
            effectiveStandardDrinks: max(0, total - 0.5),
            absorbedStandardDrinks: total,
            metabolizedStandardDrinks: 0.5,
            projectedZeroTime: Date(timeIntervalSince1970: 1_700_000_000 + 3600),
            remainingToZero: 3600,
            hydrationPlanMl: hydration,
            recommendElectrolytes: electrolytes
        )
    }

    func testMissedLogReminderTriggersWhenLeavingAfterStay() {
        let now = Date()
        let context = LocationStayContext(
            stayedDuration: 21 * 60,
            movedDistanceMeters: 260,
            lastDrinkLoggedAt: now.addingTimeInterval(-16 * 60),
            now: now
        )

        let events = service.evaluateLocationTransition(context: context)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.type, .missedLog)
    }

    func testMissedLogReminderDoesNotTriggerWithRecentDrink() {
        let now = Date()
        let context = LocationStayContext(
            stayedDuration: 25 * 60,
            movedDistanceMeters: 220,
            lastDrinkLoggedAt: now.addingTimeInterval(-10 * 60),
            now: now
        )

        let events = service.evaluateLocationTransition(context: context)
        XCTAssertTrue(events.isEmpty)
    }

    func testMissedLogReminderDoesNotTriggerWhenStayTooShort() {
        let now = Date()
        let context = LocationStayContext(
            stayedDuration: 15 * 60,
            movedDistanceMeters: 260,
            lastDrinkLoggedAt: now.addingTimeInterval(-40 * 60),
            now: now
        )

        let events = service.evaluateLocationTransition(context: context)
        XCTAssertTrue(events.isEmpty)
    }

    func testMissedLogReminderDoesNotTriggerWhenDistanceTooShort() {
        let now = Date()
        let context = LocationStayContext(
            stayedDuration: 25 * 60,
            movedDistanceMeters: 120,
            lastDrinkLoggedAt: now.addingTimeInterval(-40 * 60),
            now: now
        )

        let events = service.evaluateLocationTransition(context: context)
        XCTAssertTrue(events.isEmpty)
    }

    func testHomeHydrationReminderOnlyAfterDelay() {
        let now = Date()
        let early = HomeArrivalContext(
            arrivedAt: now.addingTimeInterval(-10 * 60),
            now: now,
            hasHydrationReminderBeenSent: false
        )
        XCTAssertTrue(service.evaluateHomeArrival(context: early, snapshot: snapshot(total: 4)).isEmpty)

        let delayed = HomeArrivalContext(
            arrivedAt: now.addingTimeInterval(-25 * 60),
            now: now,
            hasHydrationReminderBeenSent: false
        )
        XCTAssertEqual(service.evaluateHomeArrival(context: delayed, snapshot: snapshot(total: 4)).count, 1)
    }

    func testHomeHydrationReminderOnlyOncePerSession() {
        let now = Date()
        let context = HomeArrivalContext(
            arrivedAt: now.addingTimeInterval(-30 * 60),
            now: now,
            hasHydrationReminderBeenSent: true
        )

        let events = service.evaluateHomeArrival(context: context, snapshot: snapshot(total: 3))
        XCTAssertTrue(events.isEmpty)
    }

    func testHomeHydrationReminderRequiresLoggedDrinks() {
        let now = Date()
        let context = HomeArrivalContext(
            arrivedAt: now.addingTimeInterval(-30 * 60),
            now: now,
            hasHydrationReminderBeenSent: false
        )

        let events = service.evaluateHomeArrival(context: context, snapshot: snapshot(total: 0, hydration: 600))
        XCTAssertTrue(events.isEmpty)
    }
}
