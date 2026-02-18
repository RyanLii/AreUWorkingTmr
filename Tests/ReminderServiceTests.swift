import XCTest

#if canImport(SaferNightCore)
@testable import SaferNightCore
#endif

final class ReminderServiceTests: XCTestCase {
    private let service = DefaultReminderService()

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
        let snapshot = SessionSnapshot(
            date: now,
            totalStandardDrinks: 4,
            estimatedBAC: 0.06,
            intoxicationState: .social,
            saferDriveTime: now,
            remainingToSaferDrive: 0,
            hydrationPlanMl: 1200,
            recommendElectrolytes: true
        )

        let early = HomeArrivalContext(
            arrivedAt: now.addingTimeInterval(-10 * 60),
            now: now,
            hasHydrationReminderBeenSent: false
        )
        XCTAssertTrue(service.evaluateHomeArrival(context: early, snapshot: snapshot).isEmpty)

        let delayed = HomeArrivalContext(
            arrivedAt: now.addingTimeInterval(-25 * 60),
            now: now,
            hasHydrationReminderBeenSent: false
        )
        XCTAssertEqual(service.evaluateHomeArrival(context: delayed, snapshot: snapshot).count, 1)
    }

    func testHomeHydrationReminderOnlyOncePerSession() {
        let now = Date()
        let snapshot = SessionSnapshot(
            date: now,
            totalStandardDrinks: 3,
            estimatedBAC: 0.05,
            intoxicationState: .social,
            saferDriveTime: now,
            remainingToSaferDrive: 0,
            hydrationPlanMl: 900,
            recommendElectrolytes: false
        )

        let alreadySent = HomeArrivalContext(
            arrivedAt: now.addingTimeInterval(-30 * 60),
            now: now,
            hasHydrationReminderBeenSent: true
        )

        let events = service.evaluateHomeArrival(context: alreadySent, snapshot: snapshot)
        XCTAssertTrue(events.isEmpty)
    }

    func testHomeHydrationReminderRequiresLoggedDrinks() {
        let now = Date()
        let soberSnapshot = SessionSnapshot(
            date: now,
            totalStandardDrinks: 0,
            estimatedBAC: 0,
            intoxicationState: .clear,
            saferDriveTime: now,
            remainingToSaferDrive: 0,
            hydrationPlanMl: 600,
            recommendElectrolytes: false
        )

        let context = HomeArrivalContext(
            arrivedAt: now.addingTimeInterval(-30 * 60),
            now: now,
            hasHydrationReminderBeenSent: false
        )

        let events = service.evaluateHomeArrival(context: context, snapshot: soberSnapshot)
        XCTAssertTrue(events.isEmpty)
    }
}
