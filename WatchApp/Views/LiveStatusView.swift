import SwiftUI

struct LiveStatusView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showDetails = false
    @State private var clearTrendPulse = false

    private var buzzStatus: BuzzStatusDescriptor {
        BuzzStatusDescriptor.from(snapshot: store.sessionSnapshot)
    }

    private var currentEffectiveStandardDrinks: Double {
        store.sessionSnapshot.effectiveStandardDrinks
    }

    private var isCleared: Bool {
        store.sessionSnapshot.state == .cleared
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Live Status")
                        .font(WatchNightTheme.titleFont)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    Text(buzzStatus.title)
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(liveChipColor.opacity(0.34))
                        )
                }

                VStack(spacing: 6) {
                    metricRow(
                        "Chill ETA",
                        isCleared ? "All good" : DisplayFormatter.countdown(store.sessionSnapshot.remainingToZero)
                    )
                    metricRow(
                        "Back to normal-human",
                        isCleared ? "Now" : DisplayFormatter.eta(store.sessionSnapshot.projectedZeroTime)
                    )
                    metricRow("STD in your body", DisplayFormatter.standardDrinks(currentEffectiveStandardDrinks))
                }
                .watchCard(highlighted: true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Cooling off progress")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)
                        Spacer()
                        Text("\(Int((cooledOffProgress * 100).rounded()))% cooled off")
                            .font(WatchNightTheme.captionFont.weight(.bold))
                            .foregroundStyle(.white)
                    }

                    clearTrendBar
                }
                .watchCard()

                Text(statusMoodCopy)
                    .font(WatchNightTheme.bodyFont)
                    .foregroundStyle(isCleared ? WatchNightTheme.mint : WatchNightTheme.warning)

                HStack {
                    Spacer()
                    Button {
                        showDetails.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Text(showDetails ? "Hide details" : "More details")
                            Image(systemName: showDetails ? "chevron.up.circle.fill" : "chevron.down.circle")
                        }
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.accentSoft)
                    }
                    .buttonStyle(.plain)
                }

                if showDetails {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nerd stuff")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.labelSoft)

                        metricRow(
                            "Total logged STD",
                            DisplayFormatter.standardDrinks(store.sessionSnapshot.totalStandardDrinks)
                        )

                        metricRow(
                            "Estimated peak SD",
                            "\(DisplayFormatter.standardDrinks(store.sessionSnapshot.estimatedPeakStandardDrinks)) at \(DisplayFormatter.eta(store.sessionSnapshot.estimatedPeakTime))"
                        )

                        if let lastDrink = store.sessionSnapshot.lastDrinkTime {
                            metricRow("Last drink", DisplayFormatter.eta(lastDrink))
                        }

                        if store.sessionSnapshot.clearingElapsed > 1,
                           (store.sessionSnapshot.state == .clearing || store.sessionSnapshot.state == .cleared) {
                            metricRow("Elapsed clearing", DisplayFormatter.duration(store.sessionSnapshot.clearingElapsed))
                        }

                        Text("Nerd math only. Estimate, not legal or medical advice.")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .watchCard()
                }

                if store.sessionSnapshot.totalStandardDrinks <= 0 {
                    Text("No drinks logged yet.")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.label)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
    }

    private var liveChipColor: Color {
        switch buzzStatus.level {
        case .underTheRadar:
            return WatchNightTheme.mint
        case .goodVibes:
            return Color(red: 0.76, green: 0.91, blue: 0.52)
        case .buzzin:
            return WatchNightTheme.accentSoft
        case .wavy:
            return WatchNightTheme.warning
        case .onFire:
            return Color(red: 0.98, green: 0.48, blue: 0.23)
        case .tooLit:
            return Color(red: 0.95, green: 0.30, blue: 0.24)
        case .takeItEasyZone:
            return Color(red: 0.78, green: 0.18, blue: 0.20)
        }
    }

    private var statusMoodCopy: String {
        if store.sessionSnapshot.state == .clearing && !isCleared {
            return "\(buzzStatus.description) Cooling off now."
        }

        return buzzStatus.description
    }

    private var cooledOffProgress: Double {
        guard let start = sessionStartTime else { return 0 }
        let end = store.sessionSnapshot.projectedZeroTime
        let total = end.timeIntervalSince(start)
        guard total > 1 else { return isCleared ? 1 : 0 }
        return min(max(Date().timeIntervalSince(start) / total, 0), 1)
    }

    private var sessionStartTime: Date? {
        let session = SessionClock.entriesInCurrentSession(store.entries, now: .now, calendar: .current)
        return session.map(\.timestamp).min()
    }

    private var clearTrendBar: some View {
        GeometryReader { proxy in
            let width = max(0, proxy.size.width * cooledOffProgress)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))

                if width > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [liveChipColor, WatchNightTheme.mint.opacity(0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width)
                        .animation(.easeInOut(duration: 0.45), value: cooledOffProgress)
                }
            }
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(clearTrendPulse ? 0.32 : 0.15), lineWidth: 1)
            )
        }
        .frame(height: 10)
        .onAppear {
            startClearTrendPulseIfNeeded()
        }
    }

    private func startClearTrendPulseIfNeeded() {
        guard !clearTrendPulse else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            clearTrendPulse = true
        }
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(WatchNightTheme.captionFont)
                .foregroundStyle(WatchNightTheme.labelSoft)
            Spacer()
            Text(value)
                .font(WatchNightTheme.bodyFont.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.74)
                .multilineTextAlignment(.trailing)
        }
    }
}
