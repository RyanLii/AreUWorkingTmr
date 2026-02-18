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
        NavigationStack {
            ZStack(alignment: .topLeading) {
                NightBackdrop()

                List {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Trust & Safety")
                                .font(NightTheme.sectionFont)
                                .foregroundStyle(.white)

                            Text("Your data stays local-first. This app gives guidance, never guarantees.")
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

                    Section("Data") {
                        Text("Drink logs and profile data stay on device, with CloudKit sync when available.")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("No account sign-in is required in V1.")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(NightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .listRowBackground(Color.clear)

                    Section("Safety & Legal") {
                        Text("BAC and drive-time are friendly estimates based on your entries and profile.")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("They are guidance only, not legal advice, legal proof, or a guarantee.")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(NightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Rules can vary by state, license type, and situation. If unsure, choose a ride and call it a good night.")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(NightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .listRowBackground(Color.clear)

                    Section("Product") {
                        Text("Version: \(appVersionText)")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Feedback: hello@areuworkingtmr.app")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(NightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Support tone: friendly assistant for tonight only, no monthly judgment.")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(NightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .listRowBackground(Color.clear)

                    Section("Analytics") {
                        Text("V1 only keeps minimal anonymous event counts.")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("No identity profile or raw dictation text is uploaded.")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(NightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .listRowBackground(Color.clear)

                    Section("Danger Zone") {
                        Button(role: .destructive) {
                            showClearAlert = true
                        } label: {
                            Text("Clear all data")
                                .font(NightTheme.bodyFont.weight(.semibold))
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .listStyle(.insetGrouped)
                .padding(.leading, 24)
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    }
}
