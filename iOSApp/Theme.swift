import SwiftUI

enum NightTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.06, green: 0.08, blue: 0.12),
            Color(red: 0.13, green: 0.18, blue: 0.23),
            Color(red: 0.24, green: 0.18, blue: 0.14)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let hazeWarm = RadialGradient(
        colors: [Color(red: 0.99, green: 0.62, blue: 0.45).opacity(0.30), .clear],
        center: .center,
        startRadius: 12,
        endRadius: 340
    )

    static let hazeCool = RadialGradient(
        colors: [Color(red: 0.42, green: 0.86, blue: 0.80).opacity(0.22), .clear],
        center: .center,
        startRadius: 10,
        endRadius: 320
    )

    static let accent = Color(red: 0.99, green: 0.53, blue: 0.36)
    static let accentSoft = Color(red: 0.98, green: 0.77, blue: 0.47)
    static let mint = Color(red: 0.47, green: 0.90, blue: 0.82)
    static let warning = Color(red: 0.99, green: 0.53, blue: 0.36)
    static let success = Color(red: 0.53, green: 0.86, blue: 0.70)

    static let card = Color.black.opacity(0.24)
    static let cardStrong = Color.black.opacity(0.34)
    static let cardStroke = Color.white.opacity(0.14)
    static let label = Color.white.opacity(0.86)
    static let labelSoft = Color.white.opacity(0.66)

    static let titleFont = Font.system(size: 38, weight: .black, design: .rounded)
    static let subtitleFont = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let sectionFont = Font.system(size: 18, weight: .bold, design: .rounded)
    static let statFont = Font.system(size: 27, weight: .heavy, design: .rounded)
    static let bodyFont = Font.system(size: 15, weight: .medium, design: .rounded)
    static let captionFont = Font.system(size: 12, weight: .semibold, design: .rounded)
}

struct NightBackdrop: View {
    var body: some View {
        ZStack {
            NightTheme.background.ignoresSafeArea()

            Circle()
                .fill(NightTheme.hazeWarm)
                .frame(width: 420, height: 420)
                .offset(x: 220, y: -340)

            Circle()
                .fill(NightTheme.hazeCool)
                .frame(width: 360, height: 360)
                .offset(x: -220, y: 360)

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 520, height: 92)
                .rotationEffect(.degrees(-9))
                .offset(x: -54, y: 290)
        }
    }
}

enum GlassProminence {
    case regular
    case high
}

struct GlassCardModifier: ViewModifier {
    let prominence: GlassProminence

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(prominence == .high ? 0.16 : 0.09),
                                        prominence == .high ? NightTheme.cardStrong : NightTheme.card
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(NightTheme.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: prominence == .high ? 16 : 10, y: 6)
            )
    }
}

extension View {
    func glassCard(_ prominence: GlassProminence = .regular) -> some View {
        modifier(GlassCardModifier(prominence: prominence))
    }
}
