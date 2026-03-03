import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "v\(version) (\(build))"
    }

    var body: some View {
        AppScreenScaffold {
            SectionCard("Last Round?") {
                bodyText("Drink tracker for iPhone and Apple Watch. Safer nights, better mornings.")
                bodyText(appVersion)
                    .foregroundStyle(NightTheme.labelSoft)
            }

            SectionCard("Safety & Disclaimer") {
                disclaimerRow(
                    "Estimates only",
                    "Session trend figures are model-based approximations, not measured values."
                )
                disclaimerRow(
                    "Not medical advice",
                    "This app does not provide health, medical, or clinical guidance of any kind."
                )
                disclaimerRow(
                    "Not a measurement device",
                    "Last Round? does not provide sensor-based alcohol measurements."
                )
                disclaimerRow(
                    "Not for safety-critical decisions",
                    "Never use this app to assess readiness for machinery operation or other safety-critical tasks."
                )
            }

            SectionCard("Contact") {
                Button {
                    if let url = URL(string: "mailto:nestroundlabs@gmail.com") {
                        openURL(url)
                    }
                } label: {
                    Text("nestroundlabs@gmail.com")
                        .font(NightTheme.bodyFont)
                        .foregroundStyle(NightTheme.accentSoft)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("About")
                    .font(NightTheme.sectionFont.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(NightTheme.bodyFont)
            .foregroundStyle(NightTheme.label)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func disclaimerRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(NightTheme.bodyFont.weight(.semibold))
                .foregroundStyle(.white)
            Text(detail)
                .font(NightTheme.captionFont)
                .foregroundStyle(NightTheme.label)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
