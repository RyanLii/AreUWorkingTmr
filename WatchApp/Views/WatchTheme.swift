import SwiftUI

enum WatchNightTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.06, green: 0.08, blue: 0.12),
            Color(red: 0.14, green: 0.18, blue: 0.24),
            Color(red: 0.24, green: 0.17, blue: 0.13)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accent = Color(red: 0.99, green: 0.54, blue: 0.37)
    static let accentSoft = Color(red: 0.98, green: 0.78, blue: 0.47)
    static let mint = Color(red: 0.48, green: 0.90, blue: 0.82)
    static let warning = Color(red: 0.99, green: 0.54, blue: 0.37)
    static let danger = Color(red: 0.95, green: 0.36, blue: 0.34)

    static let card = Color.black.opacity(0.28)
    static let cardElevated = Color.black.opacity(0.38)
    static let cardStroke = Color.white.opacity(0.13)
    static let label = Color.white.opacity(0.86)
    static let labelSoft = Color.white.opacity(0.66)

    static let titleFont = Font.system(size: 18, weight: .black, design: .rounded)
    static let bodyFont = Font.system(size: 13, weight: .medium, design: .rounded)
    static let bodyStrong = Font.system(size: 14, weight: .bold, design: .rounded)
    static let captionFont = Font.system(size: 10, weight: .semibold, design: .rounded)
}

struct WatchBackdrop: View {
    var body: some View {
        ZStack {
            WatchNightTheme.background.ignoresSafeArea()

            Circle()
                .fill(Color(red: 1.00, green: 0.63, blue: 0.44).opacity(0.30))
                .frame(width: 210, height: 210)
                .offset(x: 98, y: -106)

            Circle()
                .fill(Color(red: 0.46, green: 0.87, blue: 0.81).opacity(0.20))
                .frame(width: 170, height: 170)
                .offset(x: -86, y: 114)

            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 232, height: 54)
                .rotationEffect(.degrees(-9))
                .offset(x: -34, y: 82)
        }
    }
}

struct WatchCardModifier: ViewModifier {
    let highlighted: Bool

    func body(content: Content) -> some View {
        content
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(highlighted ? 0.16 : 0.08),
                                highlighted ? WatchNightTheme.cardElevated : WatchNightTheme.card
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(WatchNightTheme.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.22), radius: highlighted ? 10 : 7, y: 4)
            )
    }
}

extension View {
    func watchCard(highlighted: Bool = false) -> some View {
        modifier(WatchCardModifier(highlighted: highlighted))
    }
}
