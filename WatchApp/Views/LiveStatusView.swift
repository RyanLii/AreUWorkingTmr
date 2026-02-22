import SwiftUI

struct LiveStatusView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL
    @State private var showDetails = false
    @State private var clearTrendPulse = false
    @State private var statusChipPulse = false
    @State private var progressAnchorToken: String = ""
    @State private var progressAnchorSessionStart: Date?
    @State private var progressAnchorProjectedZero: Date = .now
    @State private var showCutMeOffSheet = false
    @State private var hydrationConfirmed = false
    @State private var rideConfirmed = false
    @State private var alarmConfirmed = false
    @State private var drinkIconsAppeared: [Bool] = []

    private var buzzStatus: BuzzStatusDescriptor {
        BuzzStatusDescriptor.from(snapshot: store.sessionSnapshot)
    }

    private var isCleared: Bool {
        store.sessionSnapshot.state == .cleared
    }

    private var hasSessionDrinks: Bool {
        store.sessionSnapshot.totalStandardDrinks > 0.001
    }

    private var checklistCompletedCount: Int {
        [hydrationConfirmed, rideConfirmed, alarmConfirmed].filter { $0 }.count
    }

    private var isHeavyLoad: Bool {
        store.sessionSnapshot.effectiveStandardDrinks >= 5 || store.sessionSnapshot.totalStandardDrinks >= 8
    }

    private var cutMeOffContext: String {
        let label = DoneTonightCopy.toneLabel(
            totalStandardDrinks: store.sessionSnapshot.totalStandardDrinks,
            effectiveStandardDrinks: store.sessionSnapshot.effectiveStandardDrinks,
            workingTomorrow: store.effectiveWorkingTomorrow
        )
        return "\(DisplayFormatter.standardDrinks(store.sessionSnapshot.effectiveStandardDrinks)) active - \(label)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                if hasSessionDrinks && !store.hasMarkedDoneTonight {
                    Button {
                        hydrationConfirmed = false
                        rideConfirmed = false
                        alarmConfirmed = false
                        drinkIconsAppeared = []
                        showCutMeOffSheet = true
                    } label: {
                        HStack {
                            Label("Cut Me Off", systemImage: "moon.stars.fill")
                                .font(WatchNightTheme.bodyStrong)
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "sparkles")
                                .foregroundStyle(WatchNightTheme.accentSoft)
                        }
                        .watchCard(highlighted: true)
                    }
                    .buttonStyle(.plain)
                }


                HStack {
                    Text("Live Status")
                        .font(WatchNightTheme.titleFont)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    statusBadgePill
                }

                Text(statusMoodCopy)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(liveChipColor.opacity(0.90))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
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

                    Text("Model estimate only — actual recovery varies by person. Not medical or legal advice.")
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(WatchNightTheme.label.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .watchCard()
                .onAppear { syncStableProgressAnchor() }
                .onChange(of: store.sessionSnapshot.lastDrinkTime) { _, _ in syncStableProgressAnchor() }
                .onChange(of: store.sessionSnapshot.totalStandardDrinks) { _, _ in syncStableProgressAnchor() }

                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showDetails.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Nerd stuff")
                                .font(WatchNightTheme.captionFont)
                                .foregroundStyle(WatchNightTheme.label)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(WatchNightTheme.captionFont.weight(.semibold))
                                .foregroundStyle(WatchNightTheme.accentSoft)
                                .rotationEffect(.degrees(showDetails ? 90 : 0))
                        }
                    }
                    .buttonStyle(.plain)

                    if showDetails {
                        VStack(alignment: .leading, spacing: 4) {
                            Divider()
                                .overlay(Color.white.opacity(0.12))
                                .padding(.vertical, 6)

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
                                .padding(.top, 2)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .watchCard()

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
        .sheet(isPresented: $showCutMeOffSheet) {
            cutMeOffSheet
        }
    }

    private var cutMeOffSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                liveStatusDrinkSummaryView

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Landing checklist")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)
                        Spacer()
                        Text("\(checklistCompletedCount)/3")
                            .font(WatchNightTheme.bodyStrong)
                            .foregroundStyle(.white)
                    }
                    Text("Tap to check off each item.")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.label)
                    cutMeOffToggle(title: "Hydrated", subtitle: "Finish water target", icon: "drop.fill", confirmed: hydrationConfirmed) {
                        hydrationConfirmed.toggle()
                    }
                    cutMeOffToggle(title: "Mate check-in", subtitle: "Texted someone you trust", icon: "message.fill", confirmed: rideConfirmed) {
                        rideConfirmed.toggle()
                    }
                    cutMeOffToggle(title: "Sleep setup", subtitle: "Wind down mode", icon: "alarm.fill", confirmed: alarmConfirmed) {
                        alarmConfirmed.toggle()
                    }
                }
                .watchCard()

                if isHeavyLoad {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recovery mode")
                            .font(WatchNightTheme.bodyStrong)
                            .foregroundStyle(.white)
                        Text("Big night logged. Pause drinks, hydrate, and stay with your people.")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)
                    }
                    .watchCard(highlighted: true)
                }

                Button {
                    let body = "Hey, heading home now. Can you check in on me?"
                    if let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let url = URL(string: "sms:&body=\(encoded)") {
                        openURL(url)
                    }
                } label: {
                    Label("Text Mate", systemImage: "message.fill")
                        .font(WatchNightTheme.bodyFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(.white)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .watchCard()

                Button {
                    store.markDoneTonight()
                    showCutMeOffSheet = false
                } label: {
                    Label("Perfect. Good night", systemImage: "checkmark.circle.fill")
                        .font(WatchNightTheme.bodyFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(WatchNightTheme.accent))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .presentationDetents([.medium, .large])
    }

    private var sessionDrinkEntries: [DrinkEntry] {
        SessionClock.entriesInCurrentSession(store.entries, now: .now, calendar: .current)
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var liveStatusDrinkSummaryView: some View {
        let entries = sessionDrinkEntries
        return VStack(alignment: .leading, spacing: 8) {
            Text("Tonight's haul")
                .font(WatchNightTheme.captionFont)
                .foregroundStyle(WatchNightTheme.label)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 6)], spacing: 6) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    let appeared = drinkIconsAppeared.indices.contains(index) ? drinkIconsAppeared[index] : false
                    ZStack {
                        Circle()
                            .fill(liveTint(for: entry.category).opacity(0.22))
                            .frame(width: 36, height: 36)
                        Image(systemName: liveSymbol(for: entry.category))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(liveTint(for: entry.category))
                    }
                    .offset(x: appeared ? 0 : 50, y: appeared ? 0 : 8)
                    .opacity(appeared ? 1 : 0)
                }
            }
        }
        .watchCard(highlighted: true)
        .onAppear {
            let entries = sessionDrinkEntries
            drinkIconsAppeared = Array(repeating: false, count: entries.count)
            for i in entries.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.09 + 0.1) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
                        guard drinkIconsAppeared.indices.contains(i) else { return }
                        drinkIconsAppeared[i] = true
                    }
                }
            }
        }
    }

    private func liveTint(for category: DrinkCategory) -> Color {
        switch category {
        case .beer: Color(red: 0.99, green: 0.79, blue: 0.34)
        case .wine: Color(red: 0.98, green: 0.52, blue: 0.58)
        case .shot: Color(red: 0.99, green: 0.56, blue: 0.36)
        case .cocktail: WatchNightTheme.mint
        case .spirits: Color(red: 0.99, green: 0.69, blue: 0.37)
        case .custom: Color.white
        }
    }

    private func liveSymbol(for category: DrinkCategory) -> String {
        switch category {
        case .beer: "mug.fill"
        case .wine: "wineglass.fill"
        case .shot: "drop.fill"
        case .cocktail: "takeoutbag.and.cup.and.straw.fill"
        case .spirits: "flame.fill"
        case .custom: "slider.horizontal.3"
        }
    }

    private func cutMeOffToggle(title: String, subtitle: String, icon: String, confirmed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(confirmed ? WatchNightTheme.mint : WatchNightTheme.accentSoft)
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(WatchNightTheme.bodyStrong)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.label)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: confirmed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(confirmed ? WatchNightTheme.mint : WatchNightTheme.labelSoft)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(confirmed ? 0.15 : 0.08)))
        }
        .buttonStyle(.plain)
    }

    private var statusBadgePill: some View {
        Text(buzzStatus.title)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: Color.black.opacity(0.42), radius: 1, x: 0, y: 1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                liveChipColor.opacity(0.96),
                                Color.black.opacity(0.58)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.36), lineWidth: 1.1)
                    )
            )
            .shadow(color: liveChipColor.opacity(statusChipPulse ? 0.56 : 0.30), radius: statusChipPulse ? 10 : 6, y: 2)
            .scaleEffect(statusChipPulse ? 1.02 : 1.0)
            .onAppear { startStatusChipPulseIfNeeded() }
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
                    .frame(height: 14)

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
                        .frame(width: width, height: 14)
                        .clipShape(Capsule())
                        .animation(.linear(duration: 0.5), value: clamped)

                    if recoveryX > 4 && recoveryX < totalWidth - 4 {
                        Rectangle()
                            .fill(Color.white.opacity(0.65))
                            .frame(width: 1.5, height: 12)
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
        .frame(height: 14)
    }

    private func startClearTrendPulseIfNeeded() {
        guard !clearTrendPulse else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            clearTrendPulse = true
        }
    }

    private func startStatusChipPulseIfNeeded() {
        guard !statusChipPulse else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            statusChipPulse = true
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
