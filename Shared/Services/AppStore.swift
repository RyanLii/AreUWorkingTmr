import Foundation
import SwiftData
import CoreLocation

struct PreviousSessionSummary: Identifiable {
    var id: String { sessionKey }
    let sessionDate: Date
    let sessionKey: String
    let totalStandardDrinks: Double
    let drinkCount: Int
    let peakStandardDrinks: Double
    let peakTime: Date
    let projectedZeroTime: Date
    let projectedRecoveryTime: Date
    let hydrationPlanMl: Int
    let bodyLoadPoints: [(date: Date, load: Double)]
    let drinkTimestamps: [Date]
}

protocol AppStoreSessionPolicy {
    func sessionKey(for now: Date) -> String
    func sessionInterval(containing date: Date) -> DateInterval
    func sessionEntries(from entries: [DrinkEntry], now: Date) -> [DrinkEntry]
    func inferWorkingTomorrow(now: Date) -> Bool
    func nextMorningCheckInDate(after now: Date) -> Date
}

struct DefaultAppStoreSessionPolicy: AppStoreSessionPolicy {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func sessionKey(for now: Date) -> String {
        SessionClock.key(for: now, calendar: calendar)
    }

    func sessionInterval(containing date: Date) -> DateInterval {
        SessionClock.interval(containing: date, calendar: calendar)
    }

    func sessionEntries(from entries: [DrinkEntry], now: Date) -> [DrinkEntry] {
        SessionClock.entriesInCurrentSession(entries, now: now, calendar: calendar)
    }

    // If user does not pick manually, infer from local day rhythm:
    // 11am->11am session means late night/early morning should map to the coming wake-up day.
    func inferWorkingTomorrow(now: Date) -> Bool {
        let hour = calendar.component(.hour, from: now)

        let targetDate: Date
        if hour < SessionClock.boundaryHour {
            targetDate = now
        } else {
            targetDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(24 * 3600)
        }

        let weekday = calendar.component(.weekday, from: targetDate)
        return (2...6).contains(weekday)
    }

    func nextMorningCheckInDate(after now: Date) -> Date {
        if let todayCheckIn = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: now),
           todayCheckIn > now {
            return todayCheckIn
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(24 * 3600)
        return calendar.date(bySettingHour: 9, minute: 30, second: 0, of: tomorrow) ?? tomorrow
    }
}

protocol AppStorePersistence {
    func load(modelContext: ModelContext, fallbackProfile: UserProfile) throws -> (profile: UserProfile, entries: [DrinkEntry])
    func save(entry: DrinkEntry, modelContext: ModelContext) throws
    func save(profile: UserProfile, modelContext: ModelContext) throws
    func deleteEntries(ids: Set<UUID>, modelContext: ModelContext) throws
    func clearAll(profile: UserProfile, modelContext: ModelContext) throws
}

struct SwiftDataAppStorePersistence: AppStorePersistence {
    func load(modelContext: ModelContext, fallbackProfile: UserProfile) throws -> (profile: UserProfile, entries: [DrinkEntry]) {
        let profileFetch = FetchDescriptor<UserProfileModel>()
        let profile: UserProfile

        if let storedProfile = try modelContext.fetch(profileFetch).first {
            profile = storedProfile.domain
        } else {
            modelContext.insert(UserProfileModel(profile: fallbackProfile))
            profile = fallbackProfile
        }

        let entryFetch = FetchDescriptor<DrinkRecordModel>(
            sortBy: [SortDescriptor(\DrinkRecordModel.timestamp, order: .forward)]
        )
        let entries = try modelContext.fetch(entryFetch).map(\.domain)

        try modelContext.save()
        return (profile, entries)
    }

    func save(entry: DrinkEntry, modelContext: ModelContext) throws {
        modelContext.insert(DrinkRecordModel(entry: entry))
        try modelContext.save()
    }

    func save(profile: UserProfile, modelContext: ModelContext) throws {
        let fetch = FetchDescriptor<UserProfileModel>()
        if let existing = try modelContext.fetch(fetch).first {
            existing.update(from: profile)
        } else {
            modelContext.insert(UserProfileModel(profile: profile))
        }

        try modelContext.save()
    }

    func deleteEntries(ids: Set<UUID>, modelContext: ModelContext) throws {
        guard !ids.isEmpty else { return }

        let fetch = FetchDescriptor<DrinkRecordModel>()
        let all = try modelContext.fetch(fetch)

        for model in all where ids.contains(model.id) {
            modelContext.delete(model)
        }

        try modelContext.save()
    }

    func clearAll(profile: UserProfile, modelContext: ModelContext) throws {
        let entryFetch = FetchDescriptor<DrinkRecordModel>()
        for entry in try modelContext.fetch(entryFetch) {
            modelContext.delete(entry)
        }

        let profileFetch = FetchDescriptor<UserProfileModel>()
        for model in try modelContext.fetch(profileFetch) {
            modelContext.delete(model)
        }

        modelContext.insert(UserProfileModel(profile: profile))
        try modelContext.save()
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var entries: [DrinkEntry] = []
    @Published var profile: UserProfile = .default
    @Published private(set) var reminders: [ReminderEvent] = []
    @Published private(set) var hasMarkedDoneTonight = false
    @Published private(set) var doneTonightAt: Date?
    @Published private(set) var effectiveWorkingTomorrow = false
    @Published private(set) var isWorkingTomorrowAuto = true
    @Published private(set) var sessionSnapshot: SessionSnapshot = SessionSnapshot(
        date: .now,
        totalStandardDrinks: 0,
        effectiveStandardDrinks: 0,
        absorbedStandardDrinks: 0,
        metabolizedStandardDrinks: 0,
        projectedZeroTime: .now,
        remainingToZero: 0,
        hydrationPlanMl: 200,
        recommendElectrolytes: false
    )
    @Published private(set) var reviewRequestNonce: Int = 0

    private let estimationService: EstimationService
    private let reminderService: ReminderService
    private let persistence: AppStorePersistence
    private let sessionPolicy: AppStoreSessionPolicy
    private var modelContext: ModelContext?

    weak var connectivity: ConnectivityService?

    private var hasHomeHydrationReminderBeenSent = false
    private var hasMorningCheckInScheduled = false
    private var activeSessionKey: String?
    private var hasManualWorkingTomorrowForSession = false

    private let reviewSessionsCountKey = "app.review.sessions.count"
    private let reviewPromptMilestones: Set<Int> = [3, 8, 15]

    private static let customBasePreset = DrinkPreset(
        id: "custom",
        name: "Custom",
        category: .custom,
        defaultVolumeMl: 180,
        defaultABV: 12
    )

    init(
        estimationService: EstimationService = DefaultEstimationService(),
        reminderService: ReminderService = DefaultReminderService(),
        persistence: AppStorePersistence = SwiftDataAppStorePersistence(),
        sessionPolicy: AppStoreSessionPolicy = DefaultAppStoreSessionPolicy()
    ) {
        self.estimationService = estimationService
        self.reminderService = reminderService
        self.persistence = persistence
        self.sessionPolicy = sessionPolicy
    }

    func bind(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadFromStore()
    }

    func quickAddPresets() -> [DrinkPreset] {
        DrinkCategory.allCases.map { preset(for: $0) }
    }

    func preset(for category: DrinkCategory) -> DrinkPreset {
        let base = basePreset(for: category)
        return profile.preferredPreset(for: category, fallback: base)
    }

    func projectedSnapshot(adding preset: DrinkPreset, count: Int = 1, now: Date = .now) -> SessionSnapshot {
        refreshSessionStateIfNeeded(now: now)
        let effectiveProfile = effectiveProfileForSession(now: now, updatePublishedState: false)
        let currentSessionEntries = sessionEntries(now: now)

        guard count > 0 else {
            return estimationService.recalculate(entries: currentSessionEntries, profile: effectiveProfile, now: now)
        }

        var projectedEntries = currentSessionEntries
        for _ in 0..<count {
            let projectedEntry = estimationService.makeEntry(
                category: preset.category,
                servingName: preset.name,
                volumeMl: preset.defaultVolumeMl,
                abvPercent: preset.defaultABV,
                source: .quick,
                timestamp: now,
                locationSnapshot: nil,
                region: effectiveProfile.regionStandard
            )
            projectedEntries.append(projectedEntry)
        }

        return estimationService.recalculate(entries: projectedEntries, profile: effectiveProfile, now: now)
    }

    func setPreferredPreset(category: DrinkCategory, name: String, volumeMl: Double, abvPercent: Double) {
        var next = profile
        next.drinkPreferences[category.rawValue] = DrinkPreference(
            name: name,
            volumeMl: min(max(volumeMl, 20), 2000),
            abvPercent: min(max(abvPercent, 0.5), 80)
        )

        updateProfile(next)
    }

    func resetPreferredPreset(category: DrinkCategory) {
        guard profile.drinkPreferences[category.rawValue] != nil else { return }
        var next = profile
        next.drinkPreferences.removeValue(forKey: category.rawValue)
        updateProfile(next)
    }

    func setWorkingTomorrowForCurrentSession(_ value: Bool) {
        refreshSessionStateIfNeeded(now: .now)
        hasManualWorkingTomorrowForSession = true

        if profile.workingTomorrow == value {
            recalculateSnapshot(now: .now)
            return
        }

        var next = profile
        next.workingTomorrow = value
        profile = next
        persist(profile: next)
        recalculateSnapshot(now: .now)
    }

    func clearWorkingTomorrowOverrideForSession() {
        guard hasManualWorkingTomorrowForSession else { return }
        hasManualWorkingTomorrowForSession = false
        recalculateSnapshot(now: .now)
    }

    func addQuickDrink(preset: DrinkPreset, count: Int = 1, source: DrinkSource = .quick, location: CLLocationCoordinate2D? = nil) {
        guard count > 0 else { return }
        refreshSessionStateIfNeeded(now: .now)
        hasMarkedDoneTonight = false
        doneTonightAt = nil

        var newEntries: [DrinkEntry] = []
        for _ in 0..<count {
            let entry = estimationService.makeEntry(
                category: preset.category,
                servingName: preset.name,
                volumeMl: preset.defaultVolumeMl,
                abvPercent: preset.defaultABV,
                source: source,
                timestamp: .now,
                locationSnapshot: location.map(LocationSnapshot.init),
                region: profile.regionStandard
            )
            entries.append(entry)
            persist(entry: entry)
            newEntries.append(entry)
        }

        connectivity?.sendDrinksAdded(newEntries)
        recalculateSnapshot(now: .now)
    }

    func addVoiceDrink(parsed: ParsedDrinkIntent, location: CLLocationCoordinate2D? = nil) {
        refreshSessionStateIfNeeded(now: .now)

        let fallbackPreset = preset(for: parsed.category)
        let quantity = max(parsed.quantity, 1)
        hasMarkedDoneTonight = false
        doneTonightAt = nil

        var newEntries: [DrinkEntry] = []
        for _ in 0..<quantity {
            let volume = parsed.volumeMl ?? fallbackPreset.defaultVolumeMl
            let abv = parsed.abvPercent ?? fallbackPreset.defaultABV
            let entry = estimationService.makeEntry(
                category: parsed.category,
                servingName: fallbackPreset.name,
                volumeMl: volume,
                abvPercent: abv,
                source: .voice,
                timestamp: .now,
                locationSnapshot: location.map(LocationSnapshot.init),
                region: profile.regionStandard
            )
            entries.append(entry)
            persist(entry: entry)
            newEntries.append(entry)
        }

        connectivity?.sendDrinksAdded(newEntries)
        recalculateSnapshot(now: .now)
    }

    func canUndoLastDrink(now: Date = .now) -> Bool {
        guard let last = sessionEntries(now: now).last else { return false }
        return now.timeIntervalSince(last.timestamp) <= 60
    }

    @discardableResult
    func undoLastDrink(now: Date = .now) -> Bool {
        guard let last = sessionEntries(now: now).last,
              now.timeIntervalSince(last.timestamp) <= 60
        else {
            return false
        }

        entries.removeAll(where: { $0.id == last.id })
        deletePersistedEntries(ids: [last.id])
        connectivity?.sendDrinksDeleted([last.id])
        recalculateSnapshot(now: now)
        return true
    }

    func deleteEntries(at offsets: IndexSet) {
        let ids = Set(offsets.compactMap { entries[safe: $0]?.id })
        for index in offsets.sorted(by: >) where entries.indices.contains(index) {
            entries.remove(at: index)
        }
        deletePersistedEntries(ids: ids)
        connectivity?.sendDrinksDeleted(ids)
        recalculateSnapshot(now: .now)
    }

    func deleteEntries(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        entries.removeAll(where: { ids.contains($0.id) })
        deletePersistedEntries(ids: ids)
        connectivity?.sendDrinksDeleted(ids)
        recalculateSnapshot(now: .now)
    }

    func markReminderAcknowledged(_ reminderID: UUID) {
        if let idx = reminders.firstIndex(where: { $0.id == reminderID }) {
            reminders[idx].acknowledged = true
        }
    }

    func refreshSnapshot(now: Date = .now) {
        recalculateSnapshot(now: now)
    }

    func updateProfile(_ newProfile: UserProfile) {
        if newProfile.workingTomorrow != profile.workingTomorrow {
            hasManualWorkingTomorrowForSession = true
        }

        profile = newProfile
        persist(profile: newProfile)
        connectivity?.sendProfileUpdated(newProfile)
        recalculateSnapshot(now: .now)
    }

    func markDoneTonight(now: Date = .now) {
        refreshSessionStateIfNeeded(now: now)
        hasMarkedDoneTonight = true
        doneTonightAt = now
        connectivity?.sendDoneTonight()
        // Fallback schedule so hydration support still works even when home-location detection is unavailable.
        handleHomeArrival(arrivedAt: now, now: now)
        scheduleMorningCheckInIfNeeded(now: now)
        registerDoneSessionForReview()
    }

    func clearAllData() {
        entries = []
        reminders = []
        hasMarkedDoneTonight = false
        doneTonightAt = nil
        hasHomeHydrationReminderBeenSent = false
        hasMorningCheckInScheduled = false
        hasManualWorkingTomorrowForSession = false
        activeSessionKey = nil
        profile = .default
        effectiveWorkingTomorrow = false
        isWorkingTomorrowAuto = true
        reviewRequestNonce = 0
        UserDefaults.standard.removeObject(forKey: reviewSessionsCountKey)
        cancelAllScheduledReminders()
        recalculateSnapshot(now: .now)
        clearPersistedModels()
        connectivity?.sendClearAll()
    }

    func handleLocationTransition(stayedDuration: TimeInterval, movedDistanceMeters: Double, now: Date = .now) {
        refreshSessionStateIfNeeded(now: now)
        guard !hasMarkedDoneTonight else { return }

        let currentSession = sessionEntries(now: now)
        let context = LocationStayContext(
            stayedDuration: stayedDuration,
            movedDistanceMeters: movedDistanceMeters,
            lastDrinkLoggedAt: currentSession.last?.timestamp,
            lastMissedLogReminderAt: currentSessionLastReminderTime(type: .missedLog, now: now),
            now: now
        )

        let events = reminderService.evaluateLocationTransition(context: context)
        append(events: events)
    }

    func handleHomeArrival(arrivedAt: Date, now: Date = .now) {
        refreshSessionStateIfNeeded(now: now)
        guard sessionSnapshot.totalStandardDrinks > 0 else { return }

        let context = HomeArrivalContext(
            arrivedAt: arrivedAt,
            now: now,
            hasHydrationReminderBeenSent: hasHomeHydrationReminderBeenSent
        )

        let events = reminderService.evaluateHomeArrival(context: context, snapshot: sessionSnapshot)
        if events.contains(where: { $0.type == .homeHydration }) {
            hasHomeHydrationReminderBeenSent = true
        }

        append(events: events)
    }

    private func append(events: [ReminderEvent]) {
        guard !events.isEmpty else { return }
        reminders.append(contentsOf: events)

        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["AUTO_WATCH_DEMO"] == "1" {
            return
        }
        #endif

        Task {
            await reminderService.scheduleNotifications(events: events)
        }
    }

    private func recalculateSnapshot(now: Date) {
        refreshSessionStateIfNeeded(now: now)
        let sessionDrinks = sessionEntries(now: now)
        let effectiveProfile = effectiveProfileForSession(now: now, updatePublishedState: true)
        sessionSnapshot = estimationService.recalculate(entries: sessionDrinks, profile: effectiveProfile, now: now)
    }

    private func effectiveProfileForSession(now: Date, updatePublishedState: Bool) -> UserProfile {
        let sessionWorkingTomorrow: Bool
        let autoMode: Bool

        if hasManualWorkingTomorrowForSession {
            autoMode = false
            sessionWorkingTomorrow = profile.workingTomorrow
        } else {
            autoMode = true
            sessionWorkingTomorrow = sessionPolicy.inferWorkingTomorrow(now: now)
        }

        if updatePublishedState {
            isWorkingTomorrowAuto = autoMode
            effectiveWorkingTomorrow = sessionWorkingTomorrow
        }

        var effective = profile
        effective.workingTomorrow = sessionWorkingTomorrow
        return effective
    }

    private func sessionEntries(now: Date) -> [DrinkEntry] {
        sessionPolicy.sessionEntries(from: entries, now: now)
    }

    private func refreshSessionStateIfNeeded(now: Date) {
        let key = sessionPolicy.sessionKey(for: now)
        guard key != activeSessionKey else { return }
        let hasExistingSession = activeSessionKey != nil

        activeSessionKey = key
        hasMarkedDoneTonight = false
        doneTonightAt = nil
        hasHomeHydrationReminderBeenSent = false
        hasMorningCheckInScheduled = false
        hasManualWorkingTomorrowForSession = false

        let window = sessionPolicy.sessionInterval(containing: now)
        reminders.removeAll(where: { !window.contains($0.triggerTime) })
        if hasExistingSession {
            cancelAllScheduledReminders()
        }
    }

    private func scheduleMorningCheckInIfNeeded(now: Date) {
        guard !hasMorningCheckInScheduled else { return }
        guard sessionSnapshot.totalStandardDrinks > 0 else { return }

        let checkInTime = sessionPolicy.nextMorningCheckInDate(after: now)
        let total = sessionSnapshot.totalStandardDrinks
        let message: String

        if total >= 6 {
            message = "Morning check: big night. Sip water slowly, eat something light, and take it easy today."
        } else if total >= 3 {
            message = "Morning check: hope you slept well. A glass of water and a proper breakfast will set you up."
        } else {
            message = "Morning check: light night — you should be feeling pretty good. Stay hydrated."
        }

        let event = ReminderEvent(
            type: .morningCheckIn,
            triggerTime: checkInTime,
            context: message
        )

        hasMorningCheckInScheduled = true
        append(events: [event])
    }

    private func basePreset(for category: DrinkCategory) -> DrinkPreset {
        if category == .custom {
            return Self.customBasePreset
        }

        return regionBaselinePreset(for: category, region: profile.regionStandard)
    }

    private func regionBaselinePreset(for category: DrinkCategory, region: RegionStandard) -> DrinkPreset {
        switch (category, region) {
        case (.beer, .au10g):
            return DrinkPreset(name: "Schooner", category: .beer, defaultVolumeMl: 425, defaultABV: 4.8)
        case (.beer, .uk8g):
            return DrinkPreset(name: "Pint", category: .beer, defaultVolumeMl: 568, defaultABV: 4.5)
        case (.beer, .us14g):
            return DrinkPreset(name: "12oz Can", category: .beer, defaultVolumeMl: 355, defaultABV: 5.0)

        case (.wine, .au10g):
            return DrinkPreset(name: "Standard", category: .wine, defaultVolumeMl: 150, defaultABV: 12.5)
        case (.wine, .uk8g):
            return DrinkPreset(name: "175ml", category: .wine, defaultVolumeMl: 175, defaultABV: 12.0)
        case (.wine, .us14g):
            return DrinkPreset(name: "5oz Pour", category: .wine, defaultVolumeMl: 148, defaultABV: 12.0)

        case (.shot, .au10g):
            return DrinkPreset(name: "Classic", category: .shot, defaultVolumeMl: 45, defaultABV: 40.0)
        case (.shot, .uk8g):
            return DrinkPreset(name: "Single", category: .shot, defaultVolumeMl: 25, defaultABV: 40.0)
        case (.shot, .us14g):
            return DrinkPreset(name: "1.5oz", category: .shot, defaultVolumeMl: 44, defaultABV: 40.0)

        case (.cocktail, _):
            return DrinkPreset(name: "Standard", category: .cocktail, defaultVolumeMl: 180, defaultABV: 18.0)

        case (.spirits, .au10g):
            return DrinkPreset(name: "Single", category: .spirits, defaultVolumeMl: 45, defaultABV: 40.0)
        case (.spirits, .uk8g):
            return DrinkPreset(name: "Single", category: .spirits, defaultVolumeMl: 25, defaultABV: 40.0)
        case (.spirits, .us14g):
            return DrinkPreset(name: "Single", category: .spirits, defaultVolumeMl: 45, defaultABV: 40.0)

        case (.custom, _):
            return Self.customBasePreset
        }
    }

    private func loadFromStore() {
        guard let modelContext else {
            recalculateSnapshot(now: .now)
            return
        }

        do {
            let loaded = try persistence.load(modelContext: modelContext, fallbackProfile: profile)
            profile = loaded.profile
            entries = loaded.entries
            recalculateSnapshot(now: .now)
        } catch {
            #if DEBUG
            print("Failed loading persisted data: \(error)")
            #endif
            recalculateSnapshot(now: .now)
        }
    }

    private func persist(entry: DrinkEntry) {
        guard let modelContext else { return }

        do {
            try persistence.save(entry: entry, modelContext: modelContext)
        } catch {
            logPersistenceError("persisting drink entry", error: error)
        }
    }

    private func persist(profile: UserProfile) {
        guard let modelContext else { return }

        do {
            try persistence.save(profile: profile, modelContext: modelContext)
        } catch {
            logPersistenceError("persisting profile", error: error)
        }
    }

    private func deletePersistedEntries(ids: Set<UUID>) {
        guard let modelContext, !ids.isEmpty else { return }

        do {
            try persistence.deleteEntries(ids: ids, modelContext: modelContext)
        } catch {
            logPersistenceError("deleting entries", error: error)
        }
    }

    private func clearPersistedModels() {
        guard let modelContext else { return }

        do {
            try persistence.clearAll(profile: profile, modelContext: modelContext)
        } catch {
            logPersistenceError("clearing all data", error: error)
        }
    }

    private func logPersistenceError(_ action: String, error: Error) {
        #if DEBUG
        print("Failed \(action): \(error)")
        #endif
    }

    private func registerDoneSessionForReview() {
        let defaults = UserDefaults.standard
        let nextCount = defaults.integer(forKey: reviewSessionsCountKey) + 1
        defaults.set(nextCount, forKey: reviewSessionsCountKey)

        if reviewPromptMilestones.contains(nextCount) {
            reviewRequestNonce += 1
        }
    }

    private func currentSessionLastReminderTime(type: ReminderType, now: Date) -> Date? {
        let window = sessionPolicy.sessionInterval(containing: now)
        return reminders
            .filter { $0.type == type && window.contains($0.triggerTime) }
            .map(\.triggerTime)
            .max()
    }

    private func cancelAllScheduledReminders() {
        Task {
            await reminderService.cancelAllScheduledNotifications()
        }
    }

    func previousSessionSummary(now: Date = .now) -> PreviousSessionSummary? {
        let currentKey = sessionPolicy.sessionKey(for: now)
        let previousEntries = entries.filter {
            sessionPolicy.sessionKey(for: $0.timestamp) != currentKey
        }
        guard !previousEntries.isEmpty else { return nil }

        guard let mostRecentKey = previousEntries
            .map({ sessionPolicy.sessionKey(for: $0.timestamp) })
            .max() else { return nil }

        let sessionEntries = previousEntries.filter {
            sessionPolicy.sessionKey(for: $0.timestamp) == mostRecentKey
        }
        guard !sessionEntries.isEmpty else { return nil }

        let sessionDate = sessionPolicy.sessionInterval(
            containing: sessionEntries[0].timestamp
        ).start

        // Evaluate at last drink time so projectedZeroTime is meaningful
        let evalAt = sessionEntries.map(\.timestamp).max() ?? sessionDate
        let snap = estimationService.recalculate(entries: sessionEntries, profile: profile, now: evalAt)

        // Build body load series for the chart (5-min steps from first drink to projected clear)
        let seriesStart = sessionEntries.map(\.timestamp).min() ?? sessionDate
        let seriesEnd = snap.projectedZeroTime
        let bodyLoadPoints = buildBodyLoadSeries(
            entries: sessionEntries, profile: profile, start: seriesStart, end: seriesEnd
        )

        return PreviousSessionSummary(
            sessionDate: sessionDate,
            sessionKey: mostRecentKey,
            totalStandardDrinks: snap.totalStandardDrinks,
            drinkCount: sessionEntries.count,
            peakStandardDrinks: snap.estimatedPeakStandardDrinks,
            peakTime: snap.estimatedPeakTime,
            projectedZeroTime: snap.projectedZeroTime,
            projectedRecoveryTime: snap.projectedRecoveryTime,
            hydrationPlanMl: snap.hydrationPlanMl,
            bodyLoadPoints: bodyLoadPoints,
            drinkTimestamps: sessionEntries.map(\.timestamp)
        )
    }

    /// Early-morning summary (6–11 AM): if alcohol has cleared, show last night's session
    /// without waiting for the 11am session boundary.
    func earlyMorningSummary(now: Date = .now) -> PreviousSessionSummary? {
        let hour = Calendar.current.component(.hour, from: now)
        guard (6..<11).contains(hour) else { return nil }
        guard sessionSnapshot.effectiveStandardDrinks < 0.1 else { return nil }

        let sessionDrinks = sessionEntries(now: now)
        guard !sessionDrinks.isEmpty else { return nil }

        let sessionDate = sessionPolicy.sessionInterval(containing: sessionDrinks[0].timestamp).start
        let currentKey = sessionPolicy.sessionKey(for: now)

        let evalAt = sessionDrinks.map(\.timestamp).max() ?? sessionDate
        let snap = estimationService.recalculate(entries: sessionDrinks, profile: profile, now: evalAt)

        let seriesStart = sessionDrinks.map(\.timestamp).min() ?? sessionDate
        let seriesEnd = snap.projectedZeroTime
        let bodyLoadPoints = buildBodyLoadSeries(
            entries: sessionDrinks, profile: profile, start: seriesStart, end: seriesEnd
        )

        return PreviousSessionSummary(
            sessionDate: sessionDate,
            sessionKey: currentKey,
            totalStandardDrinks: snap.totalStandardDrinks,
            drinkCount: sessionDrinks.count,
            peakStandardDrinks: snap.estimatedPeakStandardDrinks,
            peakTime: snap.estimatedPeakTime,
            projectedZeroTime: snap.projectedZeroTime,
            projectedRecoveryTime: snap.projectedRecoveryTime,
            hydrationPlanMl: snap.hydrationPlanMl,
            bodyLoadPoints: bodyLoadPoints,
            drinkTimestamps: sessionDrinks.map(\.timestamp)
        )
    }

    func bodyLoadSeries(now: Date = .now) -> (points: [(date: Date, load: Double)], entries: [DrinkEntry]) {
        let sessionDrinks = sessionEntries(now: now)
        guard !sessionDrinks.isEmpty else { return ([], []) }
        let effectiveProfile = effectiveProfileForSession(now: now, updatePublishedState: false)
        guard let sessionStart = sessionDrinks.map(\.timestamp).min() else { return ([], []) }
        let end = sessionSnapshot.projectedZeroTime
        guard end > sessionStart else { return ([], []) }

        let points = buildBodyLoadSeries(
            entries: sessionDrinks, profile: effectiveProfile, start: sessionStart, end: end
        )
        return (points, sessionDrinks)
    }

    // MARK: - Shared helpers

    /// Builds a body-load time series at 5-min steps from `start` to `end` (inclusive).
    private func buildBodyLoadSeries(
        entries: [DrinkEntry],
        profile: UserProfile,
        start: Date,
        end: Date
    ) -> [(date: Date, load: Double)] {
        guard end > start else { return [] }
        let step: TimeInterval = 5 * 60
        var points: [(date: Date, load: Double)] = []
        var t = start
        while t <= end {
            let s = estimationService.recalculate(entries: entries, profile: profile, now: t)
            points.append((date: t, load: s.effectiveStandardDrinks))
            t += step
        }
        if points.last.map({ $0.date < end }) ?? true {
            let s = estimationService.recalculate(entries: entries, profile: profile, now: end)
            points.append((date: end, load: s.effectiveStandardDrinks))
        }
        return points
    }

    // MARK: - Remote apply (no re-broadcast to avoid loops)

    func applyRemoteDrinks(_ remoteEntries: [DrinkEntry]) {
        var changed = false
        for entry in remoteEntries {
            guard !entries.contains(where: { $0.id == entry.id }) else { continue }
            entries.append(entry)
            persist(entry: entry)
            changed = true
        }
        guard changed else { return }
        entries.sort { $0.timestamp < $1.timestamp }
        recalculateSnapshot(now: .now)
    }

    /// Full replace: reconciles local entries against the authoritative payload.
    /// Deletes entries missing from the payload, adds entries missing locally,
    /// and syncs profile + doneTonight in both directions.
    func applyFullContext(_ payload: ContextPayload) {
        let remoteIDs = Set(payload.entries.map(\.id))
        let localIDs  = Set(entries.map(\.id))

        // Delete entries that exist locally but not in the authoritative payload
        let toDelete = localIDs.subtracting(remoteIDs)
        if !toDelete.isEmpty {
            entries.removeAll(where: { toDelete.contains($0.id) })
            deletePersistedEntries(ids: toDelete)
        }

        // Add entries that are in the payload but not yet local
        var didAdd = false
        for entry in payload.entries where !localIDs.contains(entry.id) {
            entries.append(entry)
            persist(entry: entry)
            didAdd = true
        }

        if didAdd {
            entries.sort { $0.timestamp < $1.timestamp }
        }

        applyRemoteProfile(payload.profile)

        // Sync doneTonight in both directions
        if payload.hasMarkedDoneTonight {
            applyRemoteDoneTonight()
        } else {
            hasMarkedDoneTonight = false
            doneTonightAt = nil
        }

        if !toDelete.isEmpty || didAdd {
            recalculateSnapshot(now: .now)
        }
    }

    func applyRemoteDelete(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let before = entries.count
        entries.removeAll(where: { ids.contains($0.id) })
        guard entries.count != before else { return }
        deletePersistedEntries(ids: ids)
        recalculateSnapshot(now: .now)
    }

    func applyRemoteProfile(_ remoteProfile: UserProfile) {
        guard remoteProfile != profile else { return }
        profile = remoteProfile
        persist(profile: remoteProfile)
        recalculateSnapshot(now: .now)
    }

    func applyRemoteDoneTonight() {
        guard !hasMarkedDoneTonight else { return }
        hasMarkedDoneTonight = true
        doneTonightAt = .now
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
