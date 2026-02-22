import SwiftUI

struct LiveStatusView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showDetails = false
    @State private var clearTrendPulse = false
    @State private var progressAnchorToken: String = ""
    @State private var progressAnchorSessionStart: Date?
    @State private var progressAnchorProjectedZero: Date = .now

    private var buzzStatus: BuzzStatusDescriptor {
        BuzzStatusDescriptor.from(snapshot: store.sessionSnapshot)
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

                Text(statusMoodCopy)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(liveChipColor.opacity(0.90))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Cooling off progress")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)
                        Spacer()
                        SwiftUI.TimelineView(.periodic(from: .now, by: 15)) { context in
                            Text("\(Int((dynamicCooledOffProgress(at: context.date) * 100).rounded()))% cooled off")
                                .font(WatchNightTheme.captionFont.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }

                    SwiftUI.TimelineView(.periodic(from: .now, by: 15)) { context in
                        let progress = dynamicCooledOffProgress(at: context.date)
                        let recovery = recoveryFraction()
                        dualSegmentBar(progress: progress, recoveryFraction: recovery)
                    }

                    HStack {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(WatchNightTheme.warning)
                                .frame(width: 5, height: 5)
                            Text("Feel human \(DisplayFormatter.eta(store.sessionSnapshot.projectedRecoveryTime))")
                                .font(WatchNightTheme.captionFont)
                                .foregroundStyle(WatchNightTheme.warning.opacity(0.9))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            Text("Full clear \(DisplayFormatter.eta(store.sessionSnapshot.projectedZeroTime))")
                                .font(WatchNightTheme.captionFont)
                                .foregroundStyle(WatchNightTheme.label)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Circle()
                                .fill(Color(red: 0.36, green: 0.76, blue: 0.92))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
                .watchCard()
                .onAppear { syncStableProgressAnchor() }
                .onChange(of: store.sessionSnapshot.lastDrinkTime) { _, _ in syncStableProgressAnchor() }
                .onChange(of: store.sessionSnapshot.totalStandardDrinks) { _, _ in syncStableProgressAnchor() }

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
                            "Total logged",
                            DisplayFormatter.standardDrinks(store.sessionSnapshot.totalStandardDrinks)
                        )
                        metricRow(
                            "In body now",
                            DisplayFormatter.standardDrinks(store.sessionSnapshot.effectiveStandardDrinks)
                        )
                        metricRow(
                            "Still absorbing",
                            DisplayFormatter.standardDrinks(store.sessionSnapshot.pendingAbsorptionStandardDrinks)
                        )
                        metricRow(
                            "Metabolized",
                            DisplayFormatter.standardDrinks(store.sessionSnapshot.metabolizedStandardDrinks)
                        )
                        metricRow(
                            "Estimated peak",
                            "\(DisplayFormatter.standardDrinks(store.sessionSnapshot.estimatedPeakStandardDrinks)) at \(DisplayFormatter.eta(store.sessionSnapshot.estimatedPeakTime))"
                        )
                        metricRow("Feel human", DisplayFormatter.eta(store.sessionSnapshot.projectedRecoveryTime))
                        metricRow("Full clear", DisplayFormatter.eta(store.sessionSnapshot.projectedZeroTime))

                        if let lastDrink = store.sessionSnapshot.lastDrinkTime {
                            metricRow("Last drink", DisplayFormatter.eta(lastDrink))
                        }

                        if store.sessionSnapshot.clearingElapsed > 1,
                           (store.sessionSnapshot.state == .clearing || store.sessionSnapshot.state == .cleared) {
                            metricRow("Clearing for", DisplayFormatter.duration(store.sessionSnapshot.clearingElapsed))
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
            return "\(buzzStatus.description)"
        }

        return buzzStatus.description
    }

    private var sessionStartTime: Date? {
        let session = SessionClock.entriesInCurrentSession(store.entries, now: .now, calendar: .current)
        return session.map(\.timestamp).min()
    }

    private var progressSessionToken: String {
        let lastDrinkEpoch = Int(store.sessionSnapshot.lastDrinkTime?.timeIntervalSince1970 ?? 0)
        let totalBucket = Int((store.sessionSnapshot.totalStandardDrinks * 1000).rounded())
        return "\(lastDrinkEpoch)-\(totalBucket)"
    }

    private func dynamicCooledOffProgress(at now: Date) -> Double {
        let start = progressAnchorSessionStart
            ?? sessionStartTime
            ?? store.sessionSnapshot.lastDrinkTime
            ?? store.sessionSnapshot.date
        let end = !progressAnchorToken.isEmpty ? progressAnchorProjectedZero : store.sessionSnapshot.projectedZeroTime
        let total = end.timeIntervalSince(start)
        guard total > 1 else { return isCleared ? 1 : 0 }
        return min(max(now.timeIntervalSince(start) / total, 0), 1)
    }

    private func recoveryFraction() -> Double {
        let start = progressAnchorSessionStart
            ?? sessionStartTime
            ?? store.sessionSnapshot.lastDrinkTime
            ?? store.sessionSnapshot.date
        let end = !progressAnchorToken.isEmpty ? progressAnchorProjectedZero : store.sessionSnapshot.projectedZeroTime
        let total = end.timeIntervalSince(start)
        guard total > 1 else { return 0.85 }
        return min(max(store.sessionSnapshot.projectedRecoveryTime.timeIntervalSince(start) / total, 0), 1)
    }

    private func syncStableProgressAnchor() {
        if store.sessionSnapshot.totalStandardDrinks <= 0 || store.sessionSnapshot.state == .cleared {
            progressAnchorToken = ""
            progressAnchorSessionStart = nil
            progressAnchorProjectedZero = store.sessionSnapshot.projectedZeroTime
            return
        }
        let token = progressSessionToken
        guard token != progressAnchorToken else { return }
        progressAnchorToken = token
        progressAnchorSessionStart = sessionStartTime
            ?? store.sessionSnapshot.lastDrinkTime
            ?? store.sessionSnapshot.date
        progressAnchorProjectedZero = store.sessionSnapshot.projectedZeroTime
    }

    private func dualSegmentBar(progress: Double, recoveryFraction: Double) -> some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            let totalWidth = proxy.size.width
            let width = max(0, totalWidth * clamped)
            let recoveryX = max(0, min(totalWidth * min(max(recoveryFraction, 0), 1), totalWidth))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 10)

                if width > 0 {
                    let recoveryStop = min(max(recoveryX / width, 0), 1)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: WatchNightTheme.mint.opacity(0.95), location: 0),
                                    .init(color: WatchNightTheme.warning.opacity(0.88), location: recoveryStop),
                                    .init(color: Color(red: 0.20, green: 0.60, blue: 0.95), location: min(recoveryStop + 0.001, 1)),
                                    .init(color: Color(red: 0.40, green: 0.82, blue: 1.00), location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width, height: 10)
                        .clipShape(Capsule())
                        .animation(.linear(duration: 0.5), value: clamped)

                    if recoveryX > 4 && recoveryX < totalWidth - 4 {
                        Rectangle()
                            .fill(Color.white.opacity(0.65))
                            .frame(width: 1.5, height: 8)
                            .offset(x: recoveryX - 0.75)
                    }
                }
            }
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(clearTrendPulse ? 0.32 : 0.15), lineWidth: 1)
            )
            .onAppear {
                startClearTrendPulseIfNeeded()
            }
        }
        .frame(height: 10)
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
