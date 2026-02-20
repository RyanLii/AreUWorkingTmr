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
            SectionCard("Data") {
                bodyText("Drink logs and app data stay on device, with CloudKit sync when available.")
                bodyText("No account sign-in is required in V1.")
            }

            SectionCard("Model Notes") {
                bodyText("Live status shows estimated effective standard drinks in body.")
                bodyText("The model applies an absorption lag, smooth intake windows, and non-negative body-stock metabolism.")
                bodyText("Primary output is modeled time-to-clear of effective standard drinks.")
                bodyText("Guidance only, not medical advice.")
            }

            SectionCard("Product") {
                bodyText("Version: \(appVersionText)")
                bodyText("Feedback: hello@areuworkingtmr.app")
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
