import Foundation
import SwiftData

@Model
final class DrinkRecordModel {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var categoryRaw: String
    var servingName: String?
    var volumeMl: Double
    var abvPercent: Double
    var ethanolGrams: Double
    var standardDrinks: Double
    var sourceRaw: String
    var latitude: Double?
    var longitude: Double?

    init(entry: DrinkEntry) {
        self.id = entry.id
        self.timestamp = entry.timestamp
        self.categoryRaw = entry.category.rawValue
        self.servingName = entry.servingName
        self.volumeMl = entry.volumeMl
        self.abvPercent = entry.abvPercent
        self.ethanolGrams = entry.ethanolGrams
        self.standardDrinks = entry.standardDrinks
        self.sourceRaw = entry.source.rawValue
        self.latitude = entry.locationSnapshot?.latitude
        self.longitude = entry.locationSnapshot?.longitude
    }

    var domain: DrinkEntry {
        DrinkEntry(
            id: id,
            timestamp: timestamp,
            category: DrinkCategory(rawValue: categoryRaw) ?? .custom,
            servingName: servingName,
            volumeMl: volumeMl,
            abvPercent: abvPercent,
            ethanolGrams: ethanolGrams,
            standardDrinks: standardDrinks,
            source: DrinkSource(rawValue: sourceRaw) ?? .edit,
            locationSnapshot: {
                guard let latitude, let longitude else { return nil }
                return LocationSnapshot(latitude: latitude, longitude: longitude)
            }()
        )
    }
}

@Model
final class UserProfileModel {
    @Attribute(.unique) var id: String
    var weightKg: Double
    var heightCm: Double
    var biologicalSexRaw: String
    var unitPreferenceRaw: String
    var regionStandardRaw: String
    var workingTomorrow: Bool
    var homeLatitude: Double?
    var homeLongitude: Double?
    var drinkPreferencesJSON: String?

    init(profile: UserProfile, id: String = "primary") {
        self.id = id
        self.weightKg = profile.weightKg
        self.heightCm = profile.heightCm
        self.biologicalSexRaw = profile.biologicalSex.rawValue
        self.unitPreferenceRaw = profile.unitPreference.rawValue
        self.regionStandardRaw = profile.regionStandard.rawValue
        self.workingTomorrow = profile.workingTomorrow
        self.homeLatitude = profile.homeLocation?.latitude
        self.homeLongitude = profile.homeLocation?.longitude
        self.drinkPreferencesJSON = Self.encode(preferences: profile.drinkPreferences)
    }

    var domain: UserProfile {
        UserProfile(
            weightKg: weightKg,
            heightCm: heightCm,
            biologicalSex: BiologicalSex(rawValue: biologicalSexRaw) ?? .other,
            unitPreference: UnitPreference(rawValue: unitPreferenceRaw) ?? .metric,
            regionStandard: RegionStandard(rawValue: regionStandardRaw) ?? .au10g,
            workingTomorrow: workingTomorrow,
            homeLocation: {
                guard let homeLatitude, let homeLongitude else { return nil }
                return LocationSnapshot(latitude: homeLatitude, longitude: homeLongitude)
            }(),
            drinkPreferences: Self.decode(preferencesJSON: drinkPreferencesJSON)
        )
    }

    func update(from profile: UserProfile) {
        weightKg = profile.weightKg
        heightCm = profile.heightCm
        biologicalSexRaw = profile.biologicalSex.rawValue
        unitPreferenceRaw = profile.unitPreference.rawValue
        regionStandardRaw = profile.regionStandard.rawValue
        workingTomorrow = profile.workingTomorrow
        homeLatitude = profile.homeLocation?.latitude
        homeLongitude = profile.homeLocation?.longitude
        drinkPreferencesJSON = Self.encode(preferences: profile.drinkPreferences)
    }

    private static func encode(preferences: [String: DrinkPreference]) -> String {
        guard
            let data = try? JSONEncoder().encode(preferences),
            let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return string
    }

    private static func decode(preferencesJSON: String?) -> [String: DrinkPreference] {
        guard
            let preferencesJSON,
            let data = preferencesJSON.data(using: .utf8),
            let decoded = try? JSONDecoder().decode([String: DrinkPreference].self, from: data)
        else {
            return [:]
        }

        return decoded
    }
}
