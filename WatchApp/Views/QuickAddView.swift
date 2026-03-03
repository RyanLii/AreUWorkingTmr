import SwiftUI
import Combine

struct QuickAddView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var locationMonitor: WatchLocationMonitor
    @Environment(\.openURL) private var openURL

    @State private var activeCategory: DrinkCategory?
    @State private var selectedServing: ServingOption?
    @State private var selectedABV: Double = 5
    @State private var quantity: Int = 1
    @State private var manualVolumeMl: Int = 180
    @State private var showDoneTonightSheet = false
    @State private var hydrationConfirmed = false
    @State private var rideConfirmed = false
    @State private var alarmConfirmed = false
    @State private var doneTonightMessage = DoneTonightCopy.random(
        totalStandardDrinks: 0,
        effectiveStandardDrinks: 0,
        workingTomorrow: false
    )
    @State private var drinkIconsAppeared: [Bool] = []
    @State private var detailScrollToBottomToken = 0
    @State private var showStatusDetails = false
    @State private var progressAnchorToken: String = ""
    @State private var progressAnchorSessionStart: Date?
    @State private var progressAnchorProjectedZero: Date = .now

    private var presets: [DrinkPreset] {
        store.quickAddPresets()
    }

    private var sessionDrinkEntries: [DrinkEntry] {
        SessionClock.entriesInCurrentSession(store.entries, now: .now, calendar: .current)
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var checklistCompletedCount: Int {
        [hydrationConfirmed, rideConfirmed, alarmConfirmed].filter { $0 }.count
    }

    private var hasSessionDrinks: Bool {
        store.sessionSnapshot.totalStandardDrinks > 0.001
    }

    private var hasActiveLoad: Bool {
        hasSessionDrinks && store.sessionSnapshot.state != .cleared
    }

    private var currentEffectiveStandardDrinks: Double {
        store.sessionSnapshot.effectiveStandardDrinks
    }

    private var buzzStatus: BuzzStatusDescriptor {
        BuzzStatusDescriptor.from(snapshot: store.sessionSnapshot)
    }

    private var isCleared: Bool {
        store.sessionSnapshot.state == .cleared
    }

    private var isHeavyLoad: Bool {
        currentEffectiveStandardDrinks >= 5 || store.sessionSnapshot.totalStandardDrinks >= 8
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("Quick Add")
                        .font(WatchNightTheme.titleFont)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Text("Tap to choose size + ABV + count.")
                    .font(WatchNightTheme.captionFont)
                    .foregroundStyle(WatchNightTheme.labelSoft)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if hasActiveLoad && !store.hasMarkedDoneTonight {
                    Button {
                        hydrationConfirmed = false
                        rideConfirmed = false
                        alarmConfirmed = false
                        drinkIconsAppeared = []
                        refreshDoneTonightMessage()
                        showDoneTonightSheet = true
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

                if hasActiveLoad {
                    quickSessionStatusCard
                }

                if store.canUndoLastDrink() {
                    Button {
                        _ = store.undoLastDrink()
                    } label: {
                        Label("Undo Last", systemImage: "arrow.uturn.backward.circle.fill")
                            .font(WatchNightTheme.bodyFont)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .watchCard()
                    }
                    .buttonStyle(.plain)
                }

                ForEach(presets) { preset in
                    HStack(spacing: 8) {
                        Button {
                            openDetail(for: preset)
                        } label: {
                            HStack(spacing: 8) {
                                Image(customAssetName(for: preset.category))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26 * iconScale(for: preset.category), height: 26 * iconScale(for: preset.category))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(preset.category.title)
                                        .font(WatchNightTheme.bodyStrong)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)

                                    Text(presetSummary(preset))
                                        .font(WatchNightTheme.captionFont)
                                        .foregroundStyle(WatchNightTheme.label)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.82)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: "chevron.right.circle.fill")
                                    .foregroundStyle(WatchNightTheme.accentSoft)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            addDefaultDrink(preset)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(WatchNightTheme.accentSoft)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Quick add default \(preset.category.title)")
                    }
                    .watchCard()
                }
            }
            .scenePadding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .sheet(item: $activeCategory) { category in
            detailSheet(for: category)
        }
        .sheet(isPresented: $showDoneTonightSheet) {
            doneTonightSheet
        }
        .onAppear { syncStableProgressAnchor() }
        .onChange(of: store.sessionSnapshot.lastDrinkTime) { _, _ in syncStableProgressAnchor() }
        .onChange(of: store.sessionSnapshot.totalStandardDrinks) { _, _ in syncStableProgressAnchor() }
        .onReceive(NotificationCenter.default.publisher(for: .watchDemoAction)) { note in
            guard ProcessInfo.processInfo.environment["AUTO_WATCH_DEMO"] == "1" else { return }
            guard let action = note.userInfo?["action"] as? String else { return }

            switch action {
            case "tapBeer":
                openDetail(for: store.preset(for: .beer))
            case "pickBeerSize":
                let template = ServingConfig.detailTemplate(for: .beer, region: store.profile.regionStandard)
                selectedServing = template.servings.dropFirst().first ?? template.servings.first
            case "pickBeerABV":
                selectedABV = 6.0
            case "scrollBottom":
                detailScrollToBottomToken += 1
            case "logBeer":
                logSelection(for: .beer)
            case "doneTonight":
                showDoneTonightSheet = true
            default:
                break
            }
        }
    }

    private var quickSessionStatusCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Status")
                    .font(WatchNightTheme.bodyStrong)
                    .foregroundStyle(.white)
                Spacer()
                statusBadgePill
            }

            Text(statusMoodCopy)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(statusBadgeColor.opacity(0.90))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            SwiftUI.TimelineView(.periodic(from: .now, by: 15)) { context in
                let progress = dynamicCooledOffProgress(at: context.date)
                let recovery = recoveryFraction()
                dualSegmentBar(progress: progress, recoveryFraction: recovery)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(WatchNightTheme.warning)
                        .frame(width: 5, height: 5)
                    Text("Trend easing in progress")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.warning.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color(red: 0.36, green: 0.76, blue: 0.92))
                        .frame(width: 5, height: 5)
                    Text("Approaching baseline trend")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(statusTrendCopy)
                    .font(WatchNightTheme.captionFont)
                    .foregroundStyle(WatchNightTheme.labelSoft)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                // REVIEW_SAFE_MODE: timed copy kept for future internal builds.
                // Text("Low load begins~ \(DisplayFormatter.approxEta(store.sessionSnapshot.projectedRecoveryTime))")
                // Text("Settling window around \(DisplayFormatter.etaRange(store.sessionSnapshot.projectedZeroTime))")
            }

            Text("Model estimate only — actual recovery varies by person. Not a safety or medical measurement.")
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(WatchNightTheme.label.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showStatusDetails.toggle()
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
                            .rotationEffect(.degrees(showStatusDetails ? 90 : 0))
                    }
                }
                .buttonStyle(.plain)

                if showStatusDetails {
                    VStack(alignment: .leading, spacing: 4) {
                        Divider()
                            .overlay(Color.white.opacity(0.12))
                            .padding(.vertical, 6)

                        statusMetricRow("Total logged", DisplayFormatter.standardDrinks(store.sessionSnapshot.totalStandardDrinks))
                        statusMetricRow("Active load", DisplayFormatter.standardDrinks(store.sessionSnapshot.effectiveStandardDrinks))
                        statusMetricRow("In absorption", DisplayFormatter.standardDrinks(store.sessionSnapshot.pendingAbsorptionStandardDrinks))
                        statusMetricRow("Metabolized", DisplayFormatter.standardDrinks(store.sessionSnapshot.metabolizedStandardDrinks))
                        statusMetricRow("Trend phase", trendPhaseLabel)

                        Text("Trend estimates from your log entries.")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)

                        // REVIEW_SAFE_MODE: timed status rows kept for future internal builds.
                        // statusMetricRow(
                        //     "Estimated peak",
                        //     "\(DisplayFormatter.standardDrinks(store.sessionSnapshot.estimatedPeakStandardDrinks)) at \(DisplayFormatter.eta(store.sessionSnapshot.estimatedPeakTime))"
                        // )
                        // if store.sessionSnapshot.clearingElapsed > 1,
                        //    (store.sessionSnapshot.state == .clearing || store.sessionSnapshot.state == .cleared) {
                        //     statusMetricRow("Cooling for", DisplayFormatter.duration(store.sessionSnapshot.clearingElapsed))
                        // }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .watchCard(highlighted: true)
    }

    private func statusMetricRow(_ title: String, _ value: String) -> some View {
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
                                statusBadgeColor.opacity(0.96),
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
    }

    private var statusBadgeColor: Color {
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
            return "\(buzzStatus.description)."
        }

        return buzzStatus.description
    }

    private var trendPhaseLabel: String {
        switch store.sessionSnapshot.state {
        case .preAbsorption:
            return "Starting"
        case .absorbing:
            return "Rising"
        case .clearing:
            return "Easing"
        case .cleared:
            return "Settled"
        }
    }

    private var statusTrendCopy: String {
        let progress = dynamicCooledOffProgress(at: .now)
        if progress > 0.75 {
            return "Trend is flattening toward baseline."
        }
        if progress > 0.45 {
            return "Load trend is easing steadily."
        }
        if progress > 0.20 {
            return "Load trend has turned downward."
        }
        return "Trend shift is in progress."
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
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .frame(height: 14)
    }

    private var watchDrinkSummaryView: some View {
        let entries = sessionDrinkEntries
        return VStack(alignment: .leading, spacing: 8) {
            Text("Tonight's haul")
                .font(WatchNightTheme.captionFont)
                .foregroundStyle(WatchNightTheme.label)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 6)], spacing: 6) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    let appeared = drinkIconsAppeared.indices.contains(index) ? drinkIconsAppeared[index] : false
                    Image(customAssetName(for: entry.category))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36 * iconScale(for: entry.category), height: 36 * iconScale(for: entry.category))
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

    private func watchColorForCategory(for category: DrinkCategory) -> Color {
        switch category {
        case .beer: Color(red: 0.99, green: 0.79, blue: 0.34)
        case .wine: Color(red: 0.98, green: 0.52, blue: 0.58)
        case .shot: Color(red: 0.99, green: 0.56, blue: 0.36)
        case .cocktail: WatchNightTheme.mint
        case .spirits: Color(red: 0.99, green: 0.69, blue: 0.37)
        case .custom: Color.white
        }
    }

    private var doneTonightSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                watchDrinkSummaryView

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

                    doneToggleButton(
                        title: "Hydrated",
                        subtitle: "Finish water target",
                        icon: "drop.fill",
                        confirmed: hydrationConfirmed
                    ) {
                        hydrationConfirmed.toggle()
                    }

                    doneToggleButton(
                        title: "Mate check-in",
                        subtitle: "Texted someone you trust",
                        icon: "message.fill",
                        confirmed: rideConfirmed
                    ) {
                        rideConfirmed.toggle()
                    }

                    doneToggleButton(
                        title: "Sleep setup",
                        subtitle: "Wind down mode",
                        icon: "alarm.fill",
                        confirmed: alarmConfirmed
                    ) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .watchCard(highlighted: true)
                }

                Button {
                    sendBuddyText()
                } label: {
                    Label("Text Mate", systemImage: "message.fill")
                        .font(WatchNightTheme.bodyFont)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .watchCard()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Before sleep")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.label)

                    Text("Hydration target: \(DisplayFormatter.volume(store.sessionSnapshot.hydrationPlanMl, unit: store.profile.unitPreference))")
                        .font(WatchNightTheme.bodyFont)
                        .foregroundStyle(.white)

                    if store.sessionSnapshot.recommendElectrolytes {
                        Text("Electrolytes can make tomorrow smoother.")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.mint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .watchCard()

                Button {
                    store.markDoneTonight()
                    showDoneTonightSheet = false
                } label: {
                    Label("Perfect. Good night", systemImage: "checkmark.circle.fill")
                        .font(WatchNightTheme.bodyFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(WatchNightTheme.accent)
                        )
                }
                .buttonStyle(.plain)
            }
            .scenePadding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .presentationDetents([.medium, .large])
    }

    private var doneTonightContext: String {
        let label = DoneTonightCopy.toneLabel(
            totalStandardDrinks: store.sessionSnapshot.totalStandardDrinks,
            effectiveStandardDrinks: store.sessionSnapshot.effectiveStandardDrinks,
            workingTomorrow: store.effectiveWorkingTomorrow
        )
        return "\(DisplayFormatter.standardDrinks(store.sessionSnapshot.effectiveStandardDrinks)) active - \(label)"
    }

    private func refreshDoneTonightMessage() {
        doneTonightMessage = DoneTonightCopy.random(
            totalStandardDrinks: store.sessionSnapshot.totalStandardDrinks,
            effectiveStandardDrinks: store.sessionSnapshot.effectiveStandardDrinks,
            workingTomorrow: store.effectiveWorkingTomorrow
        )
    }

    private func doneToggleButton(
        title: String,
        subtitle: String,
        icon: String,
        confirmed: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(confirmed ? WatchNightTheme.mint : WatchNightTheme.label)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(WatchNightTheme.bodyFont)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.label)
                }

                Spacer()

                Image(systemName: confirmed ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(confirmed ? WatchNightTheme.mint : WatchNightTheme.label)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func sendBuddyText() {
        let body = "Hey, heading home now. Can you check in on me?"
        guard
            let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "sms:&body=\(encoded)")
        else {
            return
        }

        openURL(url)
    }

    private func detailSheet(for category: DrinkCategory) -> some View {
        let defaultPreset = store.preset(for: category)
        let template = ServingConfig.detailTemplate(for: category, region: store.profile.regionStandard)
        let selectedVolume = currentVolumeMl(category: category, defaultPreset: defaultPreset)
        let stdEstimate = estimatedStandardDrinks(volumeMl: selectedVolume, abv: selectedABV)
        let totalStdEstimate = stdEstimate * Double(quantity)

        return ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                Text("\(template.title) Details")
                    .font(WatchNightTheme.titleFont)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Volume")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)
                        Spacer()
                        Text("\(manualVolumeMl) ml")
                            .font(WatchNightTheme.bodyFont)
                            .foregroundStyle(.white)
                    }

                    Stepper(
                        value: Binding(
                            get: { manualVolumeMl },
                            set: { newValue in
                                manualVolumeMl = newValue
                                selectedServing = nil
                            }
                        ),
                        in: 30...1000,
                        step: 10
                    ) {
                        EmptyView()
                    }
                    .labelsHidden()

                    if !template.servings.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(template.servings) { option in
                                Button {
                                    selectedServing = option
                                    manualVolumeMl = Int(option.volumeMl)
                                } label: {
                                    VStack(spacing: 1) {
                                        Text(option.name)
                                            .font(WatchNightTheme.captionFont)
                                            .foregroundStyle(.white)
                                        Text("\(Int(option.volumeMl))ml")
                                            .font(.system(size: 9, weight: .regular, design: .rounded))
                                            .foregroundStyle(WatchNightTheme.label)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selectedServing == option ? WatchNightTheme.accent.opacity(0.34) : Color.white.opacity(0.10))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .watchCard()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("ABV")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)
                        Spacer()
                        Text("\(selectedABV, specifier: "%.1f")%")
                            .font(WatchNightTheme.bodyFont)
                            .foregroundStyle(.white)
                    }

                    Stepper(value: $selectedABV, in: 0.5...80, step: 0.5) {
                        EmptyView()
                    }
                    .labelsHidden()

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(template.abvOptions, id: \.self) { abv in
                            Button {
                                selectedABV = abv
                            } label: {
                                Text("\(abv, specifier: "%.1f")%")
                                    .font(WatchNightTheme.captionFont)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(.white)
                                    .background(
                                        Capsule()
                                            .fill(abs(selectedABV - abv) < 0.01 ? WatchNightTheme.accent.opacity(0.34) : Color.white.opacity(0.10))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .watchCard()

                VStack(alignment: .leading, spacing: 6) {
                    Stepper(value: $quantity, in: 1...8) {
                        HStack {
                            Text("Count")
                                .font(WatchNightTheme.captionFont)
                                .foregroundStyle(WatchNightTheme.label)
                            Spacer()
                            Text("\(quantity)x")
                                .font(WatchNightTheme.bodyFont)
                                .foregroundStyle(.white)
                        }
                    }

                    Text("Per drink: ~\(stdEstimate, specifier: "%.2f") std")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.label)

                    Text("This log: ~\(totalStdEstimate, specifier: "%.2f") std")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.label)
                }
                .watchCard()

                Button {
                    logSelection(for: category)
                } label: {
                    Label("Log \(quantity)x", systemImage: "checkmark.circle.fill")
                        .font(WatchNightTheme.bodyFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(WatchNightTheme.accent)
                        )
                }
                .id("detail-log-button")
                .buttonStyle(.plain)

                Button {
                    store.addQuickDrink(
                        preset: defaultPreset,
                        count: quantity,
                        location: locationMonitor.currentLocation?.coordinate
                    )
                    activeCategory = nil
                } label: {
                    Label("Log Saved Default", systemImage: "bolt.fill")
                        .font(WatchNightTheme.bodyFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.white.opacity(0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    saveCurrentAsDefault(for: category)
                } label: {
                    Label("Save Current as Default", systemImage: "star.fill")
                        .font(WatchNightTheme.bodyFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(WatchNightTheme.mint.opacity(0.50), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Text("Default: \(presetSummary(defaultPreset))")
                    .font(WatchNightTheme.captionFont)
                    .foregroundStyle(WatchNightTheme.label)
                }
                .scenePadding(.horizontal)
                .padding(.top, 6)
                .padding(.bottom, 10)
            }
            .onChange(of: detailScrollToBottomToken) { _, _ in
                withAnimation(.easeInOut(duration: 0.65)) {
                    proxy.scrollTo("detail-log-button", anchor: .bottom)
                }
            }
            .onAppear {
                seedDetailState(for: category, resetQuantity: false)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func openDetail(for preset: DrinkPreset) {
        seedDetailState(for: preset.category, preset: preset, resetQuantity: true)
        activeCategory = preset.category
    }

    private func addDefaultDrink(_ preset: DrinkPreset) {
        store.addQuickDrink(
            preset: preset,
            location: locationMonitor.currentLocation?.coordinate
        )
    }

    private func logSelection(for category: DrinkCategory) {
        let currentDefault = store.preset(for: category)
        let volume = currentVolumeMl(category: category, defaultPreset: currentDefault)
        let servingName = selectedServing?.name ?? currentDefault.name

        let preset = DrinkPreset(
            name: servingName,
            category: category,
            defaultVolumeMl: volume,
            defaultABV: selectedABV
        )

        store.addQuickDrink(
            preset: preset,
            count: quantity,
            location: locationMonitor.currentLocation?.coordinate
        )
        activeCategory = nil
    }

    private func saveCurrentAsDefault(for category: DrinkCategory) {
        let currentDefault = store.preset(for: category)
        let volume = currentVolumeMl(category: category, defaultPreset: currentDefault)
        let name = selectedServing?.name ?? currentDefault.name

        store.setPreferredPreset(
            category: category,
            name: name,
            volumeMl: volume,
            abvPercent: selectedABV
        )

        seedDetailState(for: category, resetQuantity: false)
    }

    private func seedDetailState(for category: DrinkCategory, preset: DrinkPreset? = nil, resetQuantity: Bool) {
        let workingPreset = preset ?? store.preset(for: category)
        selectedABV = workingPreset.defaultABV
        manualVolumeMl = Int(workingPreset.defaultVolumeMl.rounded())

        if resetQuantity {
            quantity = 1
        }

        let template = ServingConfig.detailTemplate(for: category, region: store.profile.regionStandard)
        selectedServing = template.servings.first(where: { abs($0.volumeMl - workingPreset.defaultVolumeMl) < 0.1 })
            ?? template.servings.first
    }

    private func currentVolumeMl(category: DrinkCategory, defaultPreset: DrinkPreset) -> Double {
        Double(manualVolumeMl)
    }


    private func estimatedStandardDrinks(volumeMl: Double, abv: Double) -> Double {
        let grams = max(0, volumeMl) * max(0, abv) / 100 * 0.789
        return grams / store.profile.regionStandard.gramsPerStandardDrink
    }

    private func presetSummary(_ preset: DrinkPreset) -> String {
        let categoryTitle = preset.category.title.lowercased()
        let label = preset.name.lowercased() == categoryTitle ? "" : "\(preset.name) · "
        return "\(label)\(Int(preset.defaultVolumeMl))ml · \(String(format: "%.1f", preset.defaultABV))%"
    }

    private func customAssetName(for category: DrinkCategory) -> String {
        switch category {
        case .beer: return "Beer"
        case .wine: return "Wine"
        case .shot: return "Shot"
        case .cocktail: return "Cocotail"
        case .spirits: return "Spirit"
        case .custom: return "Custom"
        }
    }

    private func colorForCategory(for category: DrinkCategory) -> Color {
        switch category {
        case .beer: return Color(red: 1.0, green: 0.76, blue: 0.23)
        case .wine: return Color(red: 0.88, green: 0.42, blue: 0.58)
        case .shot: return WatchNightTheme.warning
        case .cocktail: return WatchNightTheme.mint
        case .spirits: return Color(red: 0.99, green: 0.66, blue: 0.35)
        case .custom: return .white
        }
    }

    private func iconScale(for category: DrinkCategory) -> CGFloat {
        switch category {
        case .shot, .custom: return 1.35
        default: return 1.0
        }
    }
}
extension Notification.Name {
    static let watchDemoAction = Notification.Name("WatchDemoAction")
}

enum DoneTonightTone {
    case softStart
    case goodVibe
    case playfulMode
    case spicyMode
    case chaosMode
    case recoveryMode

    var label: String {
        switch self {
        case .softStart:
            return "Soft start"
        case .goodVibe:
            return "Good vibe"
        case .playfulMode:
            return "Playful mode"
        case .spicyMode:
            return "Spicy mode"
        case .chaosMode:
            return "Chaos mode"
        case .recoveryMode:
            return "Recovery mode"
        }
    }
}

enum DoneTonightCopy {
    static func random(totalStandardDrinks: Double, effectiveStandardDrinks: Double, workingTomorrow _: Bool) -> String {
        let tone = toneBand(totalStandardDrinks: totalStandardDrinks, effectiveStandardDrinks: effectiveStandardDrinks)
        let candidates = lines(for: tone)
        return candidates.randomElement() ?? "Great night. Hydrate and rest well."
    }

    static func toneLabel(totalStandardDrinks: Double, effectiveStandardDrinks: Double, workingTomorrow _: Bool) -> String {
        toneBand(totalStandardDrinks: totalStandardDrinks, effectiveStandardDrinks: effectiveStandardDrinks).label
    }

    private static func toneBand(totalStandardDrinks: Double, effectiveStandardDrinks: Double) -> DoneTonightTone {
        let load = max(totalStandardDrinks, effectiveStandardDrinks)

        switch load {
        case ..<1.5:
            return .softStart
        case ..<3.5:
            return .goodVibe
        case ..<6:
            return .playfulMode
        case ..<9:
            return .spicyMode
        case ..<12:
            return .chaosMode
        default:
            return .recoveryMode
        }
    }

    private static func lines(for tone: DoneTonightTone) -> [String] {
        switch tone {
        case .softStart:
            return softStart
        case .goodVibe:
            return goodVibe
        case .playfulMode:
            return playfulMode
        case .spicyMode:
            return spicyMode
        case .chaosMode:
            return chaosMode
        case .recoveryMode:
            return recoveryMode
        }
    }

    private static let softStart: [String] = [
        "One and done. Clean pacing.",
        "Light night, smart finish.",
        "Small sip energy, big brain energy.",
        "Early wrap. Tomorrow stays bright.",
        "Gentle finish is still a flex."
    ]

    private static let goodVibe: [String] = [
        "Great vibe, great timing, great exit.",
        "You kept the party and your peace.",
        "Solid session. Cleaner finish.",
        "Hydrate now, brag tomorrow.",
        "Good energy in, no regret out."
    ]

    private static let playfulMode: [String] = [
        "Stories-for-brunch territory reached.",
        "Fun level high. Decision quality still online.",
        "Perfect time to switch to water.",
        "You had your arc. Great cutoff.",
        "Fun complete. Cozy mode unlocked."
    ]

    private static let spicyMode: [String] = [
        "Night was loud. Your stop is wiser.",
        "You are in bold mode. Choose recovery mode now.",
        "Hydrate like it is your part-time job.",
        "Wrap it now and tomorrow remains workable.",
        "That was a lot. Ending now is elite."
    ]

    private static let chaosMode: [String] = [
        "Okay this is officially a lot of standard drinks.",
        "No more drinks. Water is the main character now.",
        "Big night confirmed. Soft exit required.",
        "Keep your friends close and your electrolytes closer.",
        "Legendary attendance. Recovery protocol now."
    ]

    private static let recoveryMode: [String] = [
        "Serious load reached. Stay with trusted people.",
        "No more alcohol tonight. Water and rest only.",
        "Message a friend and stick together.",
        "Water in small sips. Slow and steady.",
        "If you feel unwell, ask for help immediately."
    ]
}
