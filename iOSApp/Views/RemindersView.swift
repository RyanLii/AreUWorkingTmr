import SwiftUI

struct RemindersView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var permissionManager: PermissionManager

    var body: some View {
        NavigationStack {
            AppScreenScaffold {
                ScreenIntroCard(
                    title: "Reminder Control",
                    subtitle: "Permissions + smart nudges that help your night land clean."
                )

                SectionCard("Permissions") {
                    permissionRow("Notifications", enabled: permissionManager.notificationAuthorized)
                    permissionRow("Location", enabled: permissionManager.locationAuthorized)
                    permissionRow("HealthKit Read", enabled: permissionManager.healthKitAuthorized)

                    Button("Request all permissions") {
                        permissionManager.requestAllAtLaunch()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NightTheme.accent)
                }

                SectionCard("Smart Reminders") {
                    bullet("Missed-log trigger: stay >= 20m, move > 200m, no drink in last 15m.")
                    bullet("Home recovery trigger: one notification, 20m after home arrival.")
                    bullet("Morning check-in: one gentle nudge next morning after you tap Done Tonight.")
                }

                SectionCard("Timeline") {
                    if store.reminders.isEmpty {
                        Text("No reminders yet.")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(NightTheme.label)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.reminders.reversed()) { reminder in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(reminderLabel(for: reminder.type))
                                        .font(NightTheme.sectionFont)
                                        .foregroundStyle(.white)

                                    Text(reminder.context)
                                        .font(NightTheme.bodyFont)
                                        .foregroundStyle(NightTheme.label)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(reminder.triggerTime, style: .time)
                                        .font(NightTheme.captionFont)
                                        .foregroundStyle(NightTheme.labelSoft)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .onAppear {
                permissionManager.refreshStatus()
            }
        }
    }

    private func reminderLabel(for type: ReminderType) -> String {
        switch type {
        case .missedLog:
            return "Missed Log"
        case .homeHydration:
            return "Home Recovery"
        case .morningCheckIn:
            return "Morning Check-In"
        }
    }

    private func permissionRow(_ title: String, enabled: Bool) -> some View {
        HStack {
            Text(title)
                .font(NightTheme.bodyFont)
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(enabled ? NightTheme.success : NightTheme.warning)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(NightTheme.accentSoft)
            Text(text)
                .font(NightTheme.bodyFont)
                .foregroundStyle(NightTheme.label)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
