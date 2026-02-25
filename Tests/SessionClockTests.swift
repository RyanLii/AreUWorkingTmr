import XCTest

#if canImport(SaferNightCore)
@testable import SaferNightCore
#endif

final class SessionClockTests: XCTestCase {
    func testIntervalUses11amBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let morning = makeDate(year: 2026, month: 2, day: 16, hour: 10, minute: 0)
        let afternoon = makeDate(year: 2026, month: 2, day: 16, hour: 15, minute: 0)

        let morningWindow = SessionClock.interval(containing: morning, calendar: calendar)
        let afternoonWindow = SessionClock.interval(containing: afternoon, calendar: calendar)

        XCTAssertEqual(component(.day, from: morningWindow.start, calendar: calendar), 15)
        XCTAssertEqual(component(.hour, from: morningWindow.start, calendar: calendar), 11)
        XCTAssertEqual(component(.day, from: afternoonWindow.start, calendar: calendar), 16)
        XCTAssertEqual(component(.hour, from: afternoonWindow.start, calendar: calendar), 11)
    }

    func testEntryFilteringUsesCurrentSessionOnly() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let now = makeDate(year: 2026, month: 2, day: 16, hour: 21, minute: 0)

        let old = makeEntry(timestamp: makeDate(year: 2026, month: 2, day: 15, hour: 9, minute: 0))
        let inSession1 = makeEntry(timestamp: makeDate(year: 2026, month: 2, day: 16, hour: 13, minute: 0))
        let inSession2 = makeEntry(timestamp: makeDate(year: 2026, month: 2, day: 16, hour: 20, minute: 0))

        let filtered = SessionClock.entriesInCurrentSession([old, inSession1, inSession2], now: now, calendar: calendar)
        XCTAssertEqual(filtered.map(\.id), [inSession1.id, inSession2.id])
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? .distantPast
    }

    private func component(_ component: Calendar.Component, from date: Date, calendar: Calendar) -> Int {
        var calendar = calendar
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.component(component, from: date)
    }

    private func makeEntry(timestamp: Date) -> DrinkEntry {
        DrinkEntry(
            timestamp: timestamp,
            category: .beer,
            servingName: "Can",
            volumeMl: 355,
            abvPercent: 5,
            ethanolGrams: 14,
            standardDrinks: 1,
            source: .quick,
            locationSnapshot: nil
        )
    }
}
