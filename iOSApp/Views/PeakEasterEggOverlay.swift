import SwiftUI

struct PeakEasterEggOverlay: View {
    let triggerCount: Int
    let onDismiss: () -> Void

    // MARK: Background
    @State private var dimOpacity: Double = 0

    // MARK: Question phase
    @State private var questionOpacity: Double = 0
    @State private var questionScale: CGFloat = 1.3
    @State private var buttonsOffsetY: CGFloat = 80
    @State private var buttonsOpacity: Double = 0
    @State private var choiceLocked = false

    // MARK: Single-line display (one at a time)
    @State private var lineText: String = ""
    @State private var lineSize: CGFloat = 32
    @State private var lineOpacity: Double = 0
    @State private var lineScale: CGFloat = 1.0
    @State private var lineOffsetX: CGFloat = 0
    @State private var lineOffsetY: CGFloat = 0

    // (hidden layer uses showLine, no extra state needed)

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    // MARK: Body

    var body: some View {
        ZStack {
            Color.black
                .opacity(0.7 * dimOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            // Question + buttons (visible during question phase)
            VStack(spacing: 32) {
                Text("ARE YOU WORKING TOMORROW?")
                    .eggStyle(30)
                    .scaleEffect(questionScale)
                    .opacity(questionOpacity)

                HStack(spacing: 16) {
                    eggButton("YES") { handleChoice(true) }
                    eggButton("NO")  { handleChoice(false) }
                }
                .offset(y: buttonsOffsetY)
                .opacity(buttonsOpacity)
                .allowsHitTesting(!choiceLocked)
            }

            // One line at a time (shown after choice)
            Text(lineText)
                .eggStyle(lineSize)
                .scaleEffect(lineScale)
                .offset(x: lineOffsetX, y: lineOffsetY)
                .opacity(lineOpacity)
                .padding(.horizontal, 36)
        }
        .task { await runEntrance() }
    }

    // MARK: Button

    private func eggButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .black, design: .default))
                .foregroundStyle(.black)
                .kerning(-1)
                .frame(width: 100, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Entrance

    private func runEntrance() async {
        haptic.prepare()

        withAnimation(.easeOut(duration: 0.15)) { dimOpacity = 1 }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.58)) {
            questionScale = 1.0
            questionOpacity = 1.0
        }

        try? await Task.sleep(for: .milliseconds(800))

        withAnimation(.spring(response: 0.48, dampingFraction: 0.62)) {
            buttonsOffsetY = 0
            buttonsOpacity = 1.0
        }
    }

    // MARK: Choice

    private func handleChoice(_ isYes: Bool) {
        guard !choiceLocked else { return }
        choiceLocked = true
        haptic.impactOccurred()

        // Fade out question + buttons together
        withAnimation(.easeOut(duration: 0.3)) {
            questionOpacity = 0
            buttonsOpacity = 0
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            if isYes { await runYesSequence() } else { await runNoSequence() }
        }
    }

    // MARK: YES sequence

    private func runYesSequence() async {
        // "RESPECT." — slam 0.8 → 1.4 → 1.0
        await showLine("RESPECT.", size: 52, holdMs: 1300,
                       entrance: .slam(from: 0.8, peak: 1.4), withHaptic: true)

        // "FUTURE YOU SAYS THANKS." — slides in from above
        await showLine("FUTURE YOU SAYS THANKS.", size: 22, holdMs: 1600,
                       entrance: .fromTop)

        await showLine("DRINK WATER. GO HOME.", size: 22, holdMs: 1400, entrance: .fromBottom)

        await showExtraLineIfNeeded()
        await fadeOutAndDismiss()
    }

    // MARK: NO sequence

    private func runNoSequence() async {
        // 0.4s silence
        try? await Task.sleep(for: .milliseconds(400))

        // "OH WE'RE DOING THIS." — slam 0.8 → 1.6 → 1.0
        await showLine("OH WE'RE DOING THIS.", size: 38, holdMs: 1400,
                       entrance: .slam(from: 0.8, peak: 1.6), withHaptic: true)

        // "TEXT YOUR BOSS NOW." — flies in from left
        await showLine("TEXT YOUR BOSS NOW.", size: 22, holdMs: 1500,
                       entrance: .fromLeft)

        // "JK." — instant flash, short hold
        await showLine("JK.", size: 22, holdMs: 800,
                       entrance: .flash)

        await showLine("HYDRATE ANYWAY.", size: 24, holdMs: 1400, entrance: .fromBottom)

        await showExtraLineIfNeeded()
        await fadeOutAndDismiss()
    }

    // MARK: Line display engine

    private enum LineEntrance {
        case slam(from: CGFloat, peak: CGFloat)
        case flash
        case fromTop
        case fromBottom
        case fromLeft
    }

    private func showLine(
        _ text: String,
        size: CGFloat,
        holdMs: Int,
        entrance: LineEntrance,
        withHaptic: Bool = false
    ) async {
        lineText = text
        lineSize = size
        lineOpacity = 0
        lineOffsetX = 0
        lineOffsetY = 0
        lineScale = 1.0

        if withHaptic { haptic.impactOccurred() }

        switch entrance {
        case .slam(let from, let peak):
            lineScale = from
            withAnimation(.easeOut(duration: 0.13)) {
                lineOpacity = 1.0
                lineScale = peak
            }
            try? await Task.sleep(for: .milliseconds(140))
            withAnimation(.spring(response: 0.33, dampingFraction: 0.6)) {
                lineScale = 1.0
            }

        case .flash:
            lineScale = 0.9
            withAnimation(nil) { lineOpacity = 1.0 }
            withAnimation(.easeOut(duration: 0.1)) { lineScale = 1.3 }
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { lineScale = 1.0 }

        case .fromTop:
            lineOffsetY = -45
            withAnimation(.spring(response: 0.44, dampingFraction: 0.7)) {
                lineOpacity = 1.0
                lineOffsetY = 0
            }

        case .fromBottom:
            lineOffsetY = 50
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                lineOpacity = 1.0
                lineOffsetY = 0
            }

        case .fromLeft:
            lineOffsetX = -340
            withAnimation(.easeOut(duration: 0.22)) {
                lineOpacity = 1.0
                lineOffsetX = 0
            }
        }

        try? await Task.sleep(for: .milliseconds(holdMs))

        withAnimation(.easeOut(duration: 0.28)) { lineOpacity = 0 }
        try? await Task.sleep(for: .milliseconds(300))
    }

    // MARK: Hidden layer

    private func showExtraLineIfNeeded() async {
        switch triggerCount {
        case 5:
            await showLine("WE SEE YOU.", size: 28, holdMs: 1200, entrance: .fromBottom)
        case 10...:
            await showLine("OK STOP TOUCHING THE PEAK.", size: 24, holdMs: 1400,
                           entrance: .slam(from: 0.7, peak: 1.8), withHaptic: true)
        default:
            break
        }
    }

    // MARK: Fade out

    private func fadeOutAndDismiss() async {
        withAnimation(.easeOut(duration: 0.35)) { dimOpacity = 0 }
        try? await Task.sleep(for: .milliseconds(360))
        onDismiss()
    }
}

// MARK: - Text style

private extension Text {
    func eggStyle(_ size: CGFloat) -> some View {
        self
            .font(.system(size: size, weight: .black, design: .default))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .kerning(-1.5)
            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
    }
}
