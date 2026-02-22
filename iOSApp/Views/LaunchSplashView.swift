import SwiftUI
import Shimmer

struct LaunchSplashView: View {
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 18
    @State private var cheersOpacity: Double = 0
    @State private var cheersScale: CGFloat = 0.88
    @State private var taglineOpacity: Double = 0
    @State private var versionOpacity: Double = 0
    @State private var isShimmering = false

    private var versionText: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "v\(v)"
    }

    var body: some View {
        ZStack {
            NightTheme.background.ignoresSafeArea()

            LottieView(animationName: "Beer Bubbles", loopMode: .loop, contentMode: .scaleAspectFill)
                .ignoresSafeArea()
                .opacity(0.55)

            VStack(spacing: 20) {
                Text("Last Round?")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [NightTheme.accentSoft, .white],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
                    .shimmering(active: isShimmering, duration: 1.4, bounce: false)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                LottieView(animationName: "cheers!", loopMode: .playOnce)
                    .frame(width: 240, height: 240)
                    .opacity(cheersOpacity)
                    .scaleEffect(cheersScale)

                Text("Track tonight, protect tomorrow.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(NightTheme.accentSoft.opacity(0.85))
                    .opacity(taglineOpacity)
            }

            VStack {
                Spacer()
                Text(versionText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.28))
                    .padding(.bottom, 28)
                    .opacity(versionOpacity)
            }
        }
        .onAppear { runEntrance() }
    }

    private func runEntrance() {
        // Title fades in + rises
        withAnimation(.easeOut(duration: 0.6)) {
            titleOpacity = 1
            titleOffset = 0
        }

        // Shimmer after title appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            isShimmering = true
        }

        // Cheers animation enters with scale
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.3)) {
            cheersOpacity = 1
            cheersScale = 1
        }

        // Tagline fades in after cheers starts
        withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
            taglineOpacity = 1
        }

        // Version fades in last
        withAnimation(.easeOut(duration: 0.5).delay(1.3)) {
            versionOpacity = 1
        }
    }
}
