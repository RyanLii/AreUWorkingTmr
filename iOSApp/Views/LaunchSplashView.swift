import SwiftUI

struct LaunchSplashView: View {
    var body: some View {
        ZStack {
            NightTheme.background.ignoresSafeArea()

            LottieView(animationName: "Beer Bubbles", loopMode: .loop, contentMode: .scaleAspectFill)
                .ignoresSafeArea()
                .opacity(0.55)

            VStack(spacing: 20) {
                Text("Last Round?")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 5)

                LottieView(animationName: "cheers!", loopMode: .playOnce)
                    .frame(width: 240, height: 240)
            }
        }
    }
}
