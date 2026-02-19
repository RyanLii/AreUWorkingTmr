import SwiftUI

struct RemindersView: View {
    @EnvironmentObject private var permissionManager: PermissionManager

    var body: some View {
        AppScreenScaffold {
            ScreenIntroCard(
                title: "Reminder Control",
                subtitle: "Only the essentials: permission switches and core reminder logic."
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
                bullet("Missed-log nudge: after extended idle + movement.")
                bullet("Home recovery: one nudge shortly after arriving home.")
                bullet("Morning check-in: one gentle follow-up after Done Tonight.")
            }
        }
        .navigationTitle("Reminders")
        .onAppear {
            permissionManager.refreshStatus()
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
