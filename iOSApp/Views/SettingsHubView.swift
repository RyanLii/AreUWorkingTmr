import SwiftUI

struct SettingsHubView: View {
    var body: some View {
        AppScreenScaffold {
            ScreenIntroCard(
                title: "Settings",
                subtitle: "Only core controls: history, profile, reminders, and privacy."
            )

            SectionCard("Preferences") {
                VStack(spacing: 10) {
                    settingsLink(
                        title: "History",
                        subtitle: "See and clean timeline logs",
                        icon: "clock.arrow.circlepath",
                        tint: NightTheme.accentSoft
                    ) {
                        HistoryView()
                    }

                    settingsLink(
                        title: "Profile",
                        subtitle: "Weight, units, and defaults",
                        icon: "person.crop.circle",
                        tint: NightTheme.mint
                    ) {
                        ProfileView()
                    }

                    settingsLink(
                        title: "Reminders",
                        subtitle: "Permissions first, minimal smart nudges",
                        icon: "bell.badge",
                        tint: NightTheme.warning
                    ) {
                        RemindersView()
                    }

                    settingsLink(
                        title: "Privacy",
                        subtitle: "Trust, legal, and data controls",
                        icon: "lock.shield",
                        tint: Color.white.opacity(0.9)
                    ) {
                        PrivacyView()
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func settingsLink<Destination: View>(
        title: String,
        subtitle: String,
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
                    Text(subtitle)
                        .font(NightTheme.captionFont)
                        .foregroundStyle(NightTheme.label)
                        .fixedSize(horizontal: false, vertical: true)
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
