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
            lastMissedLogReminderAt: nil,
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
            lastMissedLogReminderAt: nil,
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
            lastMissedLogReminderAt: nil,
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
            lastMissedLogReminderAt: nil,
            now: now
        )

        let events = service.evaluateLocationTransition(context: context)
        XCTAssertTrue(events.isEmpty)
    }

    func testMissedLogReminderDoesNotTriggerWhenRecentReminderAlreadySent() {
        let now = Date()
        let context = LocationStayContext(
            stayedDuration: 24 * 60,
            movedDistanceMeters: 260,
            lastDrinkLoggedAt: now.addingTimeInterval(-40 * 60),
            lastMissedLogReminderAt: now.addingTimeInterval(-8 * 60),
            now: now
        )

        let events = service.evaluateLocationTransition(context: context)
        XCTAssertTrue(events.isEmpty)
    }

    func testHomeHydrationReminderSchedulesTwentyMinutesAfterArrival() {
        let now = Date()
        let context = HomeArrivalContext(
            arrivedAt: now,
            now: now,
            hasHydrationReminderBeenSent: false
        )
        let events = service.evaluateHomeArrival(context: context, snapshot: snapshot(total: 4))
        XCTAssertEqual(events.count, 1)
        guard let triggerTime = events.first?.triggerTime else {
            XCTFail("Expected home hydration event")
            return
        }
        XCTAssertEqual(triggerTime.timeIntervalSince(now), 20 * 60, accuracy: 1)
    }

    func testHomeHydrationReminderTriggersImmediatelyWhenAlreadyPastDelay() {
        let now = Date()
        let delayed = HomeArrivalContext(
            arrivedAt: now.addingTimeInterval(-25 * 60),
            now: now,
            hasHydrationReminderBeenSent: false
        )
        let events = service.evaluateHomeArrival(context: delayed, snapshot: snapshot(total: 4))
        XCTAssertEqual(events.count, 1)
        guard let triggerTime = events.first?.triggerTime else {
            XCTFail("Expected home hydration event")
            return
        }
        XCTAssertEqual(triggerTime.timeIntervalSince(now), 0, accuracy: 1)
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
