import Foundation
import UserNotifications

protocol ReminderService {
    func evaluateLocationTransition(context: LocationStayContext) -> [ReminderEvent]
    func evaluateHomeArrival(context: HomeArrivalContext, snapshot: SessionSnapshot) -> [ReminderEvent]
    func scheduleNotifications(events: [ReminderEvent]) async
    func cancelAllScheduledNotifications() async
}

struct DefaultReminderService: ReminderService {
    private let minStaySeconds: TimeInterval = 20 * 60
    private let minMoveDistanceMeters: Double = 200
    private let missedLogCooldown: TimeInterval = 15 * 60
    private let homeReminderDelay: TimeInterval = 20 * 60

    func evaluateLocationTransition(context: LocationStayContext) -> [ReminderEvent] {
        guard context.stayedDuration >= minStaySeconds else { return [] }
        guard context.movedDistanceMeters >= minMoveDistanceMeters else { return [] }

        if let lastDrinkLoggedAt = context.lastDrinkLoggedAt,
           context.now.timeIntervalSince(lastDrinkLoggedAt) <= missedLogCooldown {
            return []
        }

        if let lastMissedLogReminderAt = context.lastMissedLogReminderAt,
           context.now.timeIntervalSince(lastMissedLogReminderAt) <= missedLogCooldown {
            return []
        }

        let event = ReminderEvent(
            type: .missedLog,
            triggerTime: context.now,
            context: "Quick check: want to add your last drink so tonight's live standard-drink trend stays accurate?"
        )
        return [event]
    }

    func evaluateHomeArrival(context: HomeArrivalContext, snapshot: SessionSnapshot) -> [ReminderEvent] {
        guard snapshot.totalStandardDrinks > 0 else { return [] }
        guard !context.hasHydrationReminderBeenSent else { return [] }

        var message = "Landing check: sip around \(snapshot.hydrationPlanMl) ml water tonight."
        if snapshot.recommendElectrolytes {
            message += " If you have electrolytes, now is a great time."
        }

        let delayedTrigger = context.arrivedAt.addingTimeInterval(homeReminderDelay)
        let triggerTime = max(delayedTrigger, context.now)

        let event = ReminderEvent(
            type: .homeHydration,
            triggerTime: triggerTime,
            context: message
        )

        return [event]
    }

    func scheduleNotifications(events: [ReminderEvent]) async {
        let center = UNUserNotificationCenter.current()

        for event in events {
            let content = UNMutableNotificationContent()
            content.title = title(for: event.type)
            content.body = event.context
            content.sound = .default

            let secondsUntilTrigger = max(1, event.triggerTime.timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsUntilTrigger, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: event),
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                #if DEBUG
                print("Failed to schedule notification: \(error)")
                #endif
            }
        }
    }

    func cancelAllScheduledNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
    }

    private func title(for type: ReminderType) -> String {
        switch type {
        case .missedLog:
            return "Tiny check-in"
        case .homeHydration:
            return "Sweet home nudge"
        case .morningCheckIn:
            return "Morning check-in"
        }
    }

    private func notificationIdentifier(for event: ReminderEvent) -> String {
        switch event.type {
        case .missedLog:
            let bucket = Int(event.triggerTime.timeIntervalSince1970 / missedLogCooldown)
            return "reminder.missed_log.\(bucket)"
        case .homeHydration:
            return "reminder.home_hydration.\(SessionClock.key(for: event.triggerTime))"
        case .morningCheckIn:
            return "reminder.morning_check_in.\(SessionClock.key(for: event.triggerTime))"
        }
    }
}
