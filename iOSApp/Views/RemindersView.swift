import SwiftUI

struct RemindersView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var permissionManager: PermissionManager

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                NightBackdrop()

                List {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Reminder Control")
                                .font(NightTheme.sectionFont)
                                .foregroundStyle(.white)

                            Text("Permissions + smart nudges that help your night land clean.")
                                .font(NightTheme.bodyFont)
                                .foregroundStyle(NightTheme.label)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    Section("Permissions") {
                        permissionRow("Notifications", enabled: permissionManager.notificationAuthorized)
                        permissionRow("Location", enabled: permissionManager.locationAuthorized)
                        permissionRow("HealthKit Read", enabled: permissionManager.healthKitAuthorized)

                        Button("Request all permissions") {
                            permissionManager.requestAllAtLaunch()
                        }
                        .foregroundStyle(NightTheme.accent)
                    }

                    Section("Smart Reminders") {
                        Text("Missed-log trigger: stay >= 20m, move > 200m, no drink in last 15m.")
                            .foregroundStyle(NightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Home recovery trigger: one notification, 20m after home arrival.")
                            .foregroundStyle(NightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Morning check-in: one gentle nudge next morning after you tap Done Tonight.")
                            .foregroundStyle(NightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Section("Timeline") {
                        if store.reminders.isEmpty {
                            Text("No reminders yet.")
                                .foregroundStyle(NightTheme.label)
                        } else {
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
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .listStyle(.insetGrouped)
                .padding(.leading, 24)
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            Spacer()
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(enabled ? NightTheme.success : NightTheme.warning)
        }
    }
}
