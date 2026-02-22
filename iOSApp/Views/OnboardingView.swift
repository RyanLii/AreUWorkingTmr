import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var permissionManager: PermissionManager

    let onDone: () -> Void

    @State private var acknowledgedEstimate = false

    var body: some View {
        GeometryReader { proxy in
            let horizontalInset = max(20, max(proxy.safeAreaInsets.leading, proxy.safeAreaInsets.trailing) + 14)
            let contentWidth = max(0, proxy.size.width - (horizontalInset * 2))

            ZStack(alignment: .topLeading) {
                NightBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Are you working tomorrow?")
                            .font(NightTheme.titleFont)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Track tonight, protect tomorrow")
                            .font(NightTheme.subtitleFont)
                            .foregroundStyle(NightTheme.accentSoft)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Text("Log drinks in seconds on your watch. See your drink load rise and fall in real time — so you can make smarter calls on the night.")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 10) {
                            featureRow(icon: "applewatch", title: "Log in seconds", detail: "Pick the drink, size, and strength — straight from your wrist.")
                            featureRow(icon: "waveform.path.ecg", title: "Live drink estimate", detail: "Watch your drink load rise and fall in real time.")
                            featureRow(icon: "drop.fill", title: "Recovery reminders", detail: "Hydration nudge and morning check-in so tomorrow feels better.")
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("I understand these are behavioural estimates only — not medical advice.")
                                .font(NightTheme.bodyFont)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(3)
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack {
                                Spacer()
                                Toggle("", isOn: $acknowledgedEstimate)
                                    .labelsHidden()
                                    .fixedSize()
                                    .tint(NightTheme.accent)
                            }
                        }
                        .glassCard()

                        VStack(spacing: 10) {
                            Button {
                                permissionManager.requestAllAtLaunch()
                            } label: {
                                Label("Allow Notifications & Location", systemImage: "checkmark.shield.fill")
                                    .font(NightTheme.bodyFont.weight(.semibold))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(NightTheme.accent)

                            Button {
                                onDone()
                            } label: {
                                Text("Start Tonight")
                                    .font(NightTheme.bodyFont.weight(.bold))
                                    .foregroundStyle(acknowledgedEstimate ? Color.black : Color.white.opacity(0.3))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(acknowledgedEstimate ? NightTheme.success : Color.white.opacity(0.08))
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(!acknowledgedEstimate)
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.horizontal, horizontalInset)
                    .padding(.top, max(20, proxy.safeAreaInsets.top + 8))
                    .padding(.bottom, max(20, proxy.safeAreaInsets.bottom + 12))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .interactiveDismissDisabled(true)
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(NightTheme.accent)
                .font(.headline)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(NightTheme.sectionFont)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(detail)
                    .font(NightTheme.bodyFont)
                    .foregroundStyle(NightTheme.label)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
