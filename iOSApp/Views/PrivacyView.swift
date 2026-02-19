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
            ScreenIntroCard(
                title: "Trust & Safety",
                subtitle: "Your data stays local-first. This app gives guidance, never guarantees."
            )

            SectionCard("Data") {
                bodyText("Drink logs and profile data stay on device, with CloudKit sync when available.")
                bodyText("No account sign-in is required in V1.")
            }

            SectionCard("Safety & Legal") {
                bodyText("BAC and drive-time are friendly estimates based on your entries and profile.")
                bodyText("They are guidance only, not legal advice, legal proof, or a guarantee.")
                bodyText("Rules can vary by state, license type, and situation. If unsure, choose a ride and call it a good night.")
            }

            SectionCard("Product") {
                bodyText("Version: \(appVersionText)")
                bodyText("Feedback: hello@areuworkingtmr.app")
                bodyText("Support tone: friendly assistant for tonight only, no monthly judgment.")
            }

            SectionCard("Analytics") {
                bodyText("V1 only keeps minimal anonymous event counts.")
                bodyText("No identity profile or raw dictation text is uploaded.")
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
        .navigationTitle("Privacy")
        .alert("Clear all data?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                store.clearAllData()
            }
        } message: {
            Text("This deletes drink history, reminders, and profile data.")
        }
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(NightTheme.bodyFont)
            .foregroundStyle(NightTheme.label)
            .fixedSize(horizontal: false, vertical: true)
    }
}
