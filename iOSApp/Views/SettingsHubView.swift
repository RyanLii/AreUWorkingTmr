import SwiftUI

struct SettingsHubView: View {
    var body: some View {
        AppScreenScaffold {
            VStack(spacing: 10) {
                settingsLink(
                    title: "History",
                    icon: "clock.arrow.circlepath",
                    tint: NightTheme.accentSoft
                ) {
                    HistoryView()
                }

                settingsLink(
                    title: "Reminders",
                    icon: "bell.badge",
                    tint: NightTheme.warning
                ) {
                    RemindersView()
                }

                settingsLink(
                    title: "Privacy",
                    icon: "lock.shield",
                    tint: Color.white.opacity(0.9)
                ) {
                    PrivacyView()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(NightTheme.sectionFont.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func settingsLink<Destination: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(NightTheme.bodyFont.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NightTheme.labelSoft)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
