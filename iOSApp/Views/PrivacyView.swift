import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject private var store: AppStore

    @State private var showClearAlert = false

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "v\(version) (\(build))"
    }

    var body: some View {
        AppScreenScaffold {
            SectionCard("Your Data") {
                bodyText("Drink logs and app data are stored on your device. iCloud sync is used when available — no account required.")
                bodyText("Your data is never sold or shared with third parties.")
            }

            SectionCard("How the Model Works") {
                bodyText("Live status shows an estimate of how many standard drinks are still active in your body, based on what you've logged.")
                bodyText("The trend uses your logged drink timing, volume, and strength with a generalized pacing model.")
                bodyText("This is a behavioural guide only — not medical advice or a safety-readiness assessment.")
            }

            SectionCard("Product") {
                bodyText("Version: \(appVersionText)")
                bodyText("Feedback: nestroundlabs@gmail.com")
            }

            SectionCard("Analytics") {
                bodyText("We only collect minimal, anonymous usage counts to understand how the app is used.")
                bodyText("No personal data, voice recordings, or drink history is ever uploaded.")
            }

            SectionCard("Danger Zone") {
                Button(role: .destructive) {
                    showClearAlert = true
                } label: {
                    Text("Clear all data")
                        .font(NightTheme.bodyFont.weight(.semibold))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Privacy")
                    .font(NightTheme.sectionFont.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .alert("Clear all data?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                store.clearAllData()
            }
        } message: {
            Text("This deletes drink history, reminders, and app data.")
        }
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(NightTheme.bodyFont)
            .foregroundStyle(NightTheme.label)
            .fixedSize(horizontal: false, vertical: true)
    }
}
