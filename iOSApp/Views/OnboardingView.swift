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
                        Text("Last Round?")
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

                        Text("Log drinks in seconds. See your drink load rise and fall in real time — so you can make smarter calls on the night.")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 10) {
                            featureRow(icon: "applewatch", title: "Log in seconds", detail: "Pick the drink, size, and strength — straight from your wrist.")
                            featureRow(icon: "waveform.path.ecg", title: "Live drink estimate", detail: "Watch your drink load rise and fall in real time.")
                            featureRow(icon: "drop.fill", title: "Recovery reminders", detail: "Hydration nudge and morning check-in so tomorrow feels better.")
                        }
                        .glassCard()

                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
                                acknowledgedEstimate.toggle()
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("I understand")
                                        .font(NightTheme.bodyFont.weight(.bold))
                                        .foregroundStyle(.white)
                                    Text("This app provides model-based estimates only. Not medical advice, not a BAC device.")
                                        .font(NightTheme.captionFont)
                                        .foregroundStyle(NightTheme.label)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 12)

                                ZStack {
                                    Circle()
                                        .fill(acknowledgedEstimate ? NightTheme.accent : Color.clear)
                                        .frame(width: 28, height: 28)
                                    Circle()
                                        .stroke(
                                            acknowledgedEstimate ? NightTheme.accent : Color.white.opacity(0.3),
                                            lineWidth: 2
                                        )
                                        .frame(width: 28, height: 28)
                                    if acknowledgedEstimate {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .animation(.spring(response: 0.32, dampingFraction: 0.6), value: acknowledgedEstimate)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .glassCard()

                        VStack(spacing: 10) {
                            Button {
                                permissionManager.requestAllAtLaunch()
                            } label: {
                                Label("Allow Notifications & Location", systemImage: "checkmark.shield.fill")
                                    .font(NightTheme.bodyFont.weight(.semibold))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .foregroundStyle(Color.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(NightTheme.accent)
                                    )
                            }
                            .buttonStyle(.plain)

                            Button {
                                onDone()
                            } label: {
                                Text("Start Tonight")
                                    .font(NightTheme.bodyFont.weight(.bold))
                                    .foregroundStyle(acknowledgedEstimate ? Color.black : Color.white.opacity(0.3))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
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
        HStack(alignment: .center, spacing: 10) {
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
