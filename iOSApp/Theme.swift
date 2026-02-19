import SwiftUI

enum NightTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.24, green: 0.20, blue: 0.28),
            Color(red: 0.44, green: 0.32, blue: 0.34),
            Color(red: 0.86, green: 0.62, blue: 0.39)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let hazeWarm = RadialGradient(
        colors: [Color(red: 0.94, green: 0.63, blue: 0.38).opacity(0.46), .clear],
        center: .center,
        startRadius: 12,
        endRadius: 380
    )

    static let hazeCool = RadialGradient(
        colors: [Color(red: 0.55, green: 0.86, blue: 0.78).opacity(0.24), .clear],
        center: .center,
        startRadius: 10,
        endRadius: 360
    )

    static let accent = Color(red: 0.95, green: 0.45, blue: 0.25)
    static let accentSoft = Color(red: 0.96, green: 0.75, blue: 0.39)
    static let mint = Color(red: 0.58, green: 0.87, blue: 0.78)
    static let warning = Color(red: 0.97, green: 0.53, blue: 0.30)
    static let success = Color(red: 0.70, green: 0.88, blue: 0.66)

    static let card = Color(red: 0.04, green: 0.07, blue: 0.12).opacity(0.52)
    static let cardStrong = Color(red: 0.03, green: 0.05, blue: 0.09).opacity(0.70)
    static let cardStroke = Color.white.opacity(0.20)
    static let label = Color.white.opacity(0.95)
    static let labelSoft = Color.white.opacity(0.78)

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

            ToastBackdropMotif()
                .offset(x: 128, y: -214)

            Circle()
                .fill(NightTheme.hazeWarm)
                .frame(width: 470, height: 470)
                .offset(x: 210, y: -300)

            Circle()
                .fill(NightTheme.hazeCool)
                .frame(width: 410, height: 410)
                .offset(x: -220, y: 330)

            Circle()
                .fill(Color(red: 0.96, green: 0.82, blue: 0.62).opacity(0.18))
                .frame(width: 210, height: 210)
                .offset(x: -150, y: -280)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blendMode(.screen)

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.92, blue: 0.80).opacity(0.14), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 520, height: 92)
                .rotationEffect(.degrees(-9))
                .offset(x: -54, y: 292)

            JapaneseKanpaiMotif()
                .allowsHitTesting(false)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.08), .clear, Color.black.opacity(0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

private struct JapaneseKanpaiMotif: View {
    var body: some View {
        ZStack {
            Text("乾杯！")
                .font(.custom("HiraginoMinchoProN-W6", size: 106))
                .foregroundStyle(Color.white.opacity(0.12))
                .rotationEffect(.degrees(-7))
                .offset(x: 46, y: -170)

            Text("かんぱい！")
                .font(.custom("HiraginoMinchoProN-W3", size: 38))
                .foregroundStyle(Color.white.opacity(0.14))
                .rotationEffect(.degrees(11))
                .offset(x: -12, y: -88)

            Text("乾杯！！")
                .font(.custom("HiraginoSans-W6", size: 54))
                .foregroundStyle(Color.white.opacity(0.10))
                .rotationEffect(.degrees(84))
                .offset(x: -136, y: -38)
        }
    }
}

private struct ToastBackdropMotif: View {
    var body: some View {
        ZStack {
            glass(rotation: -16, handleOnLeft: false)
                .offset(x: -42, y: 8)

            glass(rotation: 16, handleOnLeft: true)
                .offset(x: 42, y: -8)

            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 10, height: 10)
                .offset(y: -56)

            Circle()
                .fill(NightTheme.accentSoft.opacity(0.20))
                .frame(width: 26, height: 26)
                .blur(radius: 1.4)
                .offset(x: 6, y: -40)
        }
        .frame(width: 220, height: 180)
        .opacity(0.74)
        .blendMode(.screen)
    }

    private func glass(rotation: Double, handleOnLeft: Bool) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                .frame(width: 72, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

            Capsule()
                .fill(Color.white.opacity(0.20))
                .frame(width: 52, height: 8)
                .offset(y: 10)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 2)
                .frame(width: 18, height: 42)
                .offset(x: handleOnLeft ? -43 : 43, y: 18)
        }
        .rotationEffect(.degrees(rotation))
        .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
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
