import Foundation
import CoreLocation

enum DrinkCategory: String, CaseIterable, Codable, Identifiable {
    case beer
    case wine
    case shot
    case cocktail
    case spirits
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beer: "Beer"
        case .wine: "Wine"
        case .shot: "Shot"
        case .cocktail: "Cocktail"
        case .spirits: "Spirits"
        case .custom: "Custom"
        }
    }
}

enum DrinkSource: String, Codable {
    case quick
    case voice
    case edit
}

enum UnitPreference: String, Codable, CaseIterable {
    case metric
    case imperial
}

enum RegionStandard: String, Codable, CaseIterable {
    case us14g
    case au10g
    case uk8g

    var gramsPerStandardDrink: Double {
        switch self {
        case .us14g: 14
        case .au10g: 10
        case .uk8g: 8
        }
    }

    var label: String {
        switch self {
        case .us14g: "US (14g)"
        case .au10g: "AU (10g)"
        case .uk8g: "UK (8g)"
        }
    }

    static func defaultForCurrentLocale(locale: Locale = .current) -> RegionStandard {
        let regionIdentifier = locale.region?.identifier.uppercased()
        switch regionIdentifier {
        case "AU", "NZ":
            return .au10g
        case "GB", "UK":
            return .uk8g
        case "US":
            return .us14g
        default:
            // Product default is AU. If locale mapping is unavailable/unknown,
            // fall back to AU sizing and standard drink definitions.
            return .au10g
        }
    }
}

struct DrinkPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let category: DrinkCategory
    let defaultVolumeMl: Double
    let defaultABV: Double

    init(id: String? = nil, name: String, category: DrinkCategory, defaultVolumeMl: Double, defaultABV: Double) {
        self.id = id ?? category.rawValue
        self.name = name
        self.category = category
        self.defaultVolumeMl = defaultVolumeMl
        self.defaultABV = defaultABV
    }

    static let `default`: [DrinkPreset] = [
        DrinkPreset(name: "Beer", category: .beer, defaultVolumeMl: 355, defaultABV: 5),
        DrinkPreset(name: "Wine", category: .wine, defaultVolumeMl: 150, defaultABV: 12),
        DrinkPreset(name: "Shot", category: .shot, defaultVolumeMl: 44, defaultABV: 40),
        DrinkPreset(name: "Cocktail", category: .cocktail, defaultVolumeMl: 180, defaultABV: 18),
        DrinkPreset(name: "Spirits", category: .spirits, defaultVolumeMl: 60, defaultABV: 40)
    ]
}

struct DrinkPreference: Codable, Hashable {
    var name: String
    var volumeMl: Double
    var abvPercent: Double

    init(name: String, volumeMl: Double, abvPercent: Double) {
        self.name = name
        self.volumeMl = volumeMl
        self.abvPercent = abvPercent
    }
}

struct LocationSnapshot: Codable, Hashable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct DrinkEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let category: DrinkCategory
    let servingName: String?
    let volumeMl: Double
    let abvPercent: Double
    let ethanolGrams: Double
    let standardDrinks: Double
    let source: DrinkSource
    let locationSnapshot: LocationSnapshot?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        category: DrinkCategory,
        servingName: String? = nil,
        volumeMl: Double,
        abvPercent: Double,
        ethanolGrams: Double,
        standardDrinks: Double,
        source: DrinkSource,
        locationSnapshot: LocationSnapshot? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.servingName = servingName
        self.volumeMl = volumeMl
        self.abvPercent = abvPercent
        self.ethanolGrams = ethanolGrams
        self.standardDrinks = standardDrinks
        self.source = source
        self.locationSnapshot = locationSnapshot
    }
}

struct UserProfile: Codable, Hashable {
    var unitPreference: UnitPreference
    var regionStandard: RegionStandard
    var workingTomorrow: Bool
    var drinkPreferences: [String: DrinkPreference]
    var weightKg: Double?

    init(
        unitPreference: UnitPreference,
        regionStandard: RegionStandard,
        workingTomorrow: Bool = false,
        drinkPreferences: [String: DrinkPreference] = [:],
        weightKg: Double? = nil
    ) {
        self.unitPreference = unitPreference
        self.regionStandard = regionStandard
        self.workingTomorrow = workingTomorrow
        self.drinkPreferences = drinkPreferences
        self.weightKg = weightKg
    }

    func preferredPreset(for category: DrinkCategory, fallback: DrinkPreset) -> DrinkPreset {
        guard let preference = drinkPreferences[category.rawValue] else {
            return fallback
        }

        return DrinkPreset(
            name: preference.name,
            category: category,
            defaultVolumeMl: preference.volumeMl,
            defaultABV: preference.abvPercent
        )
    }

    static let `default` = UserProfile(
        unitPreference: .metric,
        regionStandard: .defaultForCurrentLocale(),
        workingTomorrow: false,
        drinkPreferences: [:]
    )
}

struct SessionSnapshot: Equatable {
    var date: Date
    var totalStandardDrinks: Double
    var state: BodyLoadState = .cleared
    var effectiveStandardDrinks: Double = 0
    var absorbedStandardDrinks: Double = 0
    var pendingAbsorptionStandardDrinks: Double = 0
    var metabolizedStandardDrinks: Double = 0
    var projectedZeroTime: Date = .now
    var remainingToZero: TimeInterval = 0
    var projectedRecoveryTime: Date = .now
    var estimatedPeakStandardDrinks: Double = 0
    var estimatedPeakTime: Date = .now
    var lastDrinkTime: Date?
    var clearingStartedAt: Date?
    var clearingElapsed: TimeInterval = 0
    var hydrationPlanMl: Int
    var recommendElectrolytes: Bool
}

enum BodyLoadState: String, Codable, CaseIterable {
    case preAbsorption = "pre_absorption"
    case absorbing = "absorbing"
    case clearing = "clearing"
    case cleared = "cleared"

    var title: String {
        switch self {
        case .preAbsorption: "Pre-absorption"
        case .absorbing: "Absorbing"
        case .clearing: "Clearing"
        case .cleared: "Cleared"
        }
    }

    var supportiveCopy: String {
        switch self {
        case .preAbsorption:
            "Just logged. Body response may still be delayed."
        case .absorbing:
            "Body load is rising. Consider slowing down."
        case .clearing:
            "Body load is falling. Keep hydrating and resting."
        case .cleared:
            "Model estimates this session has cleared."
        }
    }
}

enum ReminderType: String, Codable {
    case missedLog = "missed_log"
    case homeHydration = "home_hydration"
    case morningCheckIn = "morning_check_in"
}

struct ReminderEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ReminderType
    let triggerTime: Date
    let context: String
    var acknowledged: Bool

    init(
        id: UUID = UUID(),
        type: ReminderType,
        triggerTime: Date,
        context: String,
        acknowledged: Bool = false
    ) {
        self.id = id
        self.type = type
        self.triggerTime = triggerTime
        self.context = context
        self.acknowledged = acknowledged
    }
}

struct LocationStayContext {
    let stayedDuration: TimeInterval
    let movedDistanceMeters: Double
    let lastDrinkLoggedAt: Date?
    let lastMissedLogReminderAt: Date?
    let now: Date
}

struct HomeArrivalContext {
    let arrivedAt: Date
    let now: Date
    let hasHydrationReminderBeenSent: Bool
}

enum SessionClock {
    // One session runs noon-to-noon so last night still belongs to "tonight" next morning.
    static let boundaryHour = 12

    static func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let todayBoundary = calendar.date(bySettingHour: boundaryHour, minute: 0, second: 0, of: date) ?? date
        let start: Date

        if date >= todayBoundary {
            start = todayBoundary
        } else {
            start = calendar.date(byAdding: .day, value: -1, to: todayBoundary) ?? todayBoundary
        }

        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 3600)
        return DateInterval(start: start, end: end)
    }

    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: interval(containing: date, calendar: calendar).start)
    }

    static func entriesInCurrentSession(_ entries: [DrinkEntry], now: Date, calendar: Calendar = .current) -> [DrinkEntry] {
        let session = interval(containing: now, calendar: calendar)
        return entries.filter { entry in
            entry.timestamp <= now && session.contains(entry.timestamp)
        }
    }
}
