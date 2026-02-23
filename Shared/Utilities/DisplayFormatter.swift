import Foundation

enum DisplayFormatter {
    static func standardDrinks(_ value: Double) -> String {
        String(format: "%.1f std", value)
    }

    static func eta(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        if calendar.isDate(date, inSameDayAs: now) {
            return timeFormatter.string(from: date)
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow \(timeFormatter.string(from: date))"
        }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "E h:mm a"
        return dayFormatter.string(from: date)
    }

    static func remaining(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours == 0 {
            return "\(minutes)m remaining"
        }
        return "\(hours)h \(minutes)m remaining"
    }

    static func countdown(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours == 0 {
            return "\(minutes)m"
        }
        return "\(hours)h \(minutes)m"
    }

    static func duration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours == 0 {
            return "\(minutes)m"
        }
        return "\(hours)h \(minutes)m"
    }

    static func volume(_ ml: Int, unit: UnitPreference) -> String {
        switch unit {
        case .metric:
            return "\(ml) ml"
        case .imperial:
            let oz = Double(ml) / 29.5735
            return String(format: "%.1f oz", oz)
        }
    }

    // Rounds to nearest 5 minutes — signals approximation, avoids false precision.
    static func approxEta(_ date: Date, now: Date = .now) -> String {
        let rounded = roundTo5Min(date)
        return eta(rounded, now: now)
    }

    // Returns a 15-minute window (floor-rounded) for projected times.
    // "Full clear around 2:45 – 3:00 AM" feels honest; exact minutes feel wrong.
    static func etaRange(_ date: Date, now: Date = .now) -> String {
        let lo = roundTo5Min(date.addingTimeInterval(-7.5 * 60))
        let hi = lo.addingTimeInterval(15 * 60)

        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let loStr = timeFormatter.string(from: lo)
        let hiStr = timeFormatter.string(from: hi)

        if calendar.isDate(date, inSameDayAs: now) {
            return "\(loStr) – \(hiStr)"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow \(loStr) – \(hiStr)"
        }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "E"
        return "\(dayFormatter.string(from: date)) \(loStr) – \(hiStr)"
    }

    private static func roundTo5Min(_ date: Date) -> Date {
        let interval = date.timeIntervalSinceReferenceDate
        let rounded = (interval / 300).rounded(.toNearestOrAwayFromZero) * 300
        return Date(timeIntervalSinceReferenceDate: rounded)
    }
}
