import SwiftUI

enum WatchNightTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.12, blue: 0.26),
            Color(red: 0.11, green: 0.24, blue: 0.41),
            Color(red: 0.60, green: 0.39, blue: 0.23)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accent = Color(red: 0.95, green: 0.45, blue: 0.25)
    static let accentSoft = Color(red: 0.96, green: 0.75, blue: 0.39)
    static let mint = Color(red: 0.58, green: 0.87, blue: 0.78)
    static let warning = Color(red: 0.97, green: 0.53, blue: 0.30)
    static let danger = Color(red: 0.93, green: 0.34, blue: 0.30)

    static let card = Color(red: 0.04, green: 0.07, blue: 0.12).opacity(0.52)
    static let cardElevated = Color(red: 0.03, green: 0.05, blue: 0.09).opacity(0.70)
    static let cardStroke = Color.white.opacity(0.20)
    static let label = Color.white.opacity(0.95)
    static let labelSoft = Color.white.opacity(0.78)

    static let titleFont = Font.system(size: 18, weight: .black, design: .rounded)
    static let bodyFont = Font.system(size: 13, weight: .medium, design: .rounded)
    static let bodyStrong = Font.system(size: 14, weight: .bold, design: .rounded)
    static let captionFont = Font.system(size: 10, weight: .semibold, design: .rounded)
}

struct WatchBackdrop: View {
    var body: some View {
        ZStack {
            WatchNightTheme.background.ignoresSafeArea()

            ToastWatchMotif()
                .offset(x: 68, y: -58)

            Circle()
                .fill(Color(red: 0.94, green: 0.63, blue: 0.38).opacity(0.42))
                .frame(width: 220, height: 220)
                .offset(x: 102, y: -110)

            Circle()
                .fill(Color(red: 0.55, green: 0.86, blue: 0.78).opacity(0.25))
                .frame(width: 174, height: 174)
                .offset(x: -88, y: 118)

            Circle()
                .fill(Color(red: 0.96, green: 0.82, blue: 0.62).opacity(0.18))
                .frame(width: 110, height: 110)
                .offset(x: -76, y: -98)

            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.92, blue: 0.80).opacity(0.14),
                            Color.white.opacity(0.03)
                        ],
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

private struct ToastWatchMotif: View {
    var body: some View {
        ZStack {
            glass(rotation: -14)
                .offset(x: -18, y: 6)
            glass(rotation: 14)
                .offset(x: 18, y: -6)
        }
        .frame(width: 110, height: 96)
        .opacity(0.70)
        .blendMode(.screen)
    }

    private func glass(rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.74, blue: 0.43).opacity(0.30),
                        Color(red: 0.86, green: 0.47, blue: 0.28).opacity(0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 34, height: 52)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .rotationEffect(.degrees(rotation))
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
