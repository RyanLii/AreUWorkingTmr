import SwiftUI
import Combine

private struct ServingOption: Identifiable, Hashable {
    let id: String
    let name: String
    let volumeMl: Double

    var subtitle: String {
        "\(Int(volumeMl))ml"
    }
}

private struct DrinkDetailTemplate {
    let title: String
    let servings: [ServingOption]
    let abvOptions: [Double]
    let supportsManualVolume: Bool
}

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
    @State private var detailScrollToBottomToken = 0
    @State private var showStatusDetails = false
    @State private var progressAnchorToken: String = ""
    @State private var progressAnchorSessionStart: Date?
    @State private var progressAnchorProjectedZero: Date = .now

    private var presets: [DrinkPreset] {
        store.quickAddPresets()
    }

    private var checklistCompletedCount: Int {
        [hydrationConfirmed, rideConfirmed, alarmConfirmed].filter { $0 }.count
    }

    private var hasSessionDrinks: Bool {
        store.sessionSnapshot.totalStandardDrinks > 0.001
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

                if hasSessionDrinks {
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

                if hasSessionDrinks && !store.hasMarkedDoneTonight {
                    Button {
                        hydrationConfirmed = false
                        rideConfirmed = false
                        alarmConfirmed = false
                        refreshDoneTonightMessage()
                        showDoneTonightSheet = true
                    } label: {
                        HStack {
                            Label("I'm Done Tonight", systemImage: "moon.stars.fill")
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

                ForEach(presets) { preset in
                    HStack(spacing: 8) {
                        Button {
                            openDetail(for: preset)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: symbol(for: preset.category))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(tint(for: preset.category))
                                    .frame(width: 18)

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
            .padding(.horizontal, 8)
            .padding(.leading, 8)
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
                let template = detailTemplate(for: .beer, region: store.profile.regionStandard)
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
                        statusMetricRow("In body now", DisplayFormatter.standardDrinks(store.sessionSnapshot.effectiveStandardDrinks))
                        statusMetricRow("Still absorbing", DisplayFormatter.standardDrinks(store.sessionSnapshot.pendingAbsorptionStandardDrinks))
                        statusMetricRow("Metabolized", DisplayFormatter.standardDrinks(store.sessionSnapshot.metabolizedStandardDrinks))
                        statusMetricRow("Estimated peak", "\(DisplayFormatter.standardDrinks(store.sessionSnapshot.estimatedPeakStandardDrinks)) at \(DisplayFormatter.eta(store.sessionSnapshot.estimatedPeakTime))")
                        statusMetricRow("Feel human", DisplayFormatter.eta(store.sessionSnapshot.projectedRecoveryTime))
                        statusMetricRow("Full clear", DisplayFormatter.eta(store.sessionSnapshot.projectedZeroTime))

                        if let lastDrink = store.sessionSnapshot.lastDrinkTime {
                            statusMetricRow("Last drink", DisplayFormatter.eta(lastDrink))
                        }

                        if store.sessionSnapshot.clearingElapsed > 1,
                           (store.sessionSnapshot.state == .clearing || store.sessionSnapshot.state == .cleared) {
                            statusMetricRow("Clearing for", DisplayFormatter.duration(store.sessionSnapshot.clearingElapsed))
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

    private var doneTonightSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer()
                    Button("Close") {
                        showDoneTonightSheet = false
                    }
                    .font(WatchNightTheme.captionFont)
                    .foregroundStyle(WatchNightTheme.accent)
                }

                Text("I'm Done Tonight")
                    .font(WatchNightTheme.titleFont)
                    .foregroundStyle(.white)

                Text(doneTonightContext)
                    .font(WatchNightTheme.captionFont)
                    .foregroundStyle(WatchNightTheme.label)

                Text(doneTonightMessage)
                    .font(WatchNightTheme.bodyFont)
                    .foregroundStyle(.white)
                    .watchCard(highlighted: true)

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
                    .watchCard(highlighted: true)
                }

                Button {
                    sendBuddyText()
                } label: {
                    Label("Text Mate", systemImage: "message.fill")
                        .font(WatchNightTheme.bodyFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
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
            .padding(.horizontal, 12)
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
        let template = detailTemplate(for: category, region: store.profile.regionStandard)
        let selectedVolume = currentVolumeMl(category: category, defaultPreset: defaultPreset)
        let stdEstimate = estimatedStandardDrinks(volumeMl: selectedVolume, abv: selectedABV)
        let totalStdEstimate = stdEstimate * Double(quantity)

        return ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                Text("\(template.title) Details")
                    .font(WatchNightTheme.titleFont)
                    .foregroundStyle(.white)

                if !template.servings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Size")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)

                        ForEach(template.servings) { option in
                            Button {
                                selectedServing = option
                            } label: {
                                HStack {
                                    Text(option.name)
                                        .font(WatchNightTheme.bodyFont)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(option.subtitle)
                                        .font(WatchNightTheme.captionFont)
                                        .foregroundStyle(WatchNightTheme.label)
                                    Image(systemName: selectedServing == option ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedServing == option ? WatchNightTheme.mint : WatchNightTheme.label)
                                }
                                .padding(.vertical, 3)
                            }
                            .contentShape(Rectangle())
                            .buttonStyle(.plain)
                        }
                    }
                    .watchCard()
                }

                if template.supportsManualVolume {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Volume")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)

                        Stepper(value: $manualVolumeMl, in: 30...1000, step: 10) {
                            Text("\(manualVolumeMl) ml")
                                .font(WatchNightTheme.bodyFont)
                                .foregroundStyle(.white)
                        }
                    }
                    .watchCard()
                }

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
                .padding(.horizontal, 12)
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

        let template = detailTemplate(for: category, region: store.profile.regionStandard)
        if template.supportsManualVolume {
            selectedServing = nil
            return
        }

        selectedServing = template.servings.first(where: { abs($0.volumeMl - workingPreset.defaultVolumeMl) < 0.1 })
            ?? template.servings.first
    }

    private func currentVolumeMl(category: DrinkCategory, defaultPreset: DrinkPreset) -> Double {
        if category == .custom {
            return Double(manualVolumeMl)
        }

        return selectedServing?.volumeMl ?? defaultPreset.defaultVolumeMl
    }

    private func detailTemplate(for category: DrinkCategory, region: RegionStandard) -> DrinkDetailTemplate {
        switch category {
        case .beer:
            let servings: [ServingOption]
            switch region {
            case .au10g:
                servings = [
                    ServingOption(id: "beer_pot", name: "Pot", volumeMl: 285),
                    ServingOption(id: "beer_schooner", name: "Schooner", volumeMl: 425),
                    ServingOption(id: "beer_pint_au", name: "Pint", volumeMl: 570),
                    ServingOption(id: "beer_longneck", name: "Longneck", volumeMl: 750)
                ]
            case .uk8g:
                servings = [
                    ServingOption(id: "beer_half_pint", name: "Half Pint", volumeMl: 284),
                    ServingOption(id: "beer_pint_uk", name: "Pint", volumeMl: 568),
                    ServingOption(id: "beer_can_uk", name: "Can", volumeMl: 440),
                    ServingOption(id: "beer_bottle_uk", name: "Bottle", volumeMl: 500)
                ]
            case .us14g:
                servings = [
                    ServingOption(id: "beer_can", name: "12oz Can", volumeMl: 355),
                    ServingOption(id: "beer_pint_us", name: "16oz Pint", volumeMl: 473),
                    ServingOption(id: "beer_tallboy", name: "Tallboy", volumeMl: 473),
                    ServingOption(id: "beer_bomber", name: "Bomber", volumeMl: 650)
                ]
            }

            return DrinkDetailTemplate(
                title: "Beer",
                servings: servings,
                abvOptions: [3.5, 4.2, 5.0, 6.0, 7.5, 9.0],
                supportsManualVolume: false
            )
        case .wine:
            let servings: [ServingOption]
            switch region {
            case .au10g:
                servings = [
                    ServingOption(id: "wine_small_au", name: "Small", volumeMl: 100),
                    ServingOption(id: "wine_std_au", name: "Standard", volumeMl: 150),
                    ServingOption(id: "wine_large_au", name: "Large", volumeMl: 200),
                    ServingOption(id: "wine_bottle_au", name: "Bottle", volumeMl: 750)
                ]
            case .uk8g:
                servings = [
                    ServingOption(id: "wine_125", name: "125ml", volumeMl: 125),
                    ServingOption(id: "wine_175", name: "175ml", volumeMl: 175),
                    ServingOption(id: "wine_250", name: "250ml", volumeMl: 250),
                    ServingOption(id: "wine_bottle_uk", name: "Bottle", volumeMl: 750)
                ]
            case .us14g:
                servings = [
                    ServingOption(id: "wine_5oz", name: "5oz Pour", volumeMl: 148),
                    ServingOption(id: "wine_6oz", name: "6oz Pour", volumeMl: 177),
                    ServingOption(id: "wine_9oz", name: "9oz Large", volumeMl: 266),
                    ServingOption(id: "wine_bottle_us", name: "Bottle", volumeMl: 750)
                ]
            }

            return DrinkDetailTemplate(
                title: "Wine",
                servings: servings,
                abvOptions: [9.0, 11.0, 12.0, 13.5, 15.0],
                supportsManualVolume: false
            )
        case .shot:
            let servings: [ServingOption]
            switch region {
            case .au10g:
                servings = [
                    ServingOption(id: "shot_single_au", name: "Single", volumeMl: 30),
                    ServingOption(id: "shot_classic_au", name: "Classic", volumeMl: 45),
                    ServingOption(id: "shot_double_au", name: "Double", volumeMl: 60)
                ]
            case .uk8g:
                servings = [
                    ServingOption(id: "shot_uk_single", name: "Single", volumeMl: 25),
                    ServingOption(id: "shot_uk_large", name: "Large", volumeMl: 35),
                    ServingOption(id: "shot_uk_double", name: "Double", volumeMl: 50)
                ]
            case .us14g:
                servings = [
                    ServingOption(id: "shot_1oz", name: "1oz", volumeMl: 30),
                    ServingOption(id: "shot_1_5oz", name: "1.5oz", volumeMl: 44),
                    ServingOption(id: "shot_double_us", name: "Double", volumeMl: 60)
                ]
            }

            return DrinkDetailTemplate(
                title: "Shot",
                servings: servings,
                abvOptions: [30.0, 35.0, 40.0, 45.0, 50.0],
                supportsManualVolume: false
            )
        case .cocktail:
            return DrinkDetailTemplate(
                title: "Cocktail",
                servings: [
                    ServingOption(id: "cocktail_small", name: "Small", volumeMl: 120),
                    ServingOption(id: "cocktail_standard", name: "Standard", volumeMl: 180),
                    ServingOption(id: "cocktail_tall", name: "Tall", volumeMl: 250),
                    ServingOption(id: "cocktail_jumbo", name: "Jumbo", volumeMl: 330)
                ],
                abvOptions: [8.0, 12.0, 16.0, 20.0, 24.0],
                supportsManualVolume: false
            )
        case .spirits:
            return DrinkDetailTemplate(
                title: "Spirits",
                servings: [
                    ServingOption(id: "spirits_nip", name: "Nip", volumeMl: 30),
                    ServingOption(id: "spirits_single", name: "Single", volumeMl: 45),
                    ServingOption(id: "spirits_double", name: "Double", volumeMl: 60),
                    ServingOption(id: "spirits_large", name: "Large", volumeMl: 90)
                ],
                abvOptions: [35.0, 40.0, 45.0, 50.0, 55.0],
                supportsManualVolume: false
            )
        case .custom:
            return DrinkDetailTemplate(
                title: "Custom",
                servings: [],
                abvOptions: [5.0, 8.0, 12.0, 18.0, 30.0, 40.0],
                supportsManualVolume: true
            )
        }
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

    private func symbol(for category: DrinkCategory) -> String {
        switch category {
        case .beer: return "mug.fill"
        case .wine: return "wineglass.fill"
        case .shot: return "drop.fill"
        case .cocktail: return "takeoutbag.and.cup.and.straw.fill"
        case .spirits: return "flame.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    private func tint(for category: DrinkCategory) -> Color {
        switch category {
        case .beer: return Color(red: 1.0, green: 0.76, blue: 0.23)
        case .wine: return Color(red: 0.88, green: 0.42, blue: 0.58)
        case .shot: return WatchNightTheme.warning
        case .cocktail: return WatchNightTheme.mint
        case .spirits: return Color(red: 0.99, green: 0.66, blue: 0.35)
        case .custom: return .white
        }
    }
}
extension Notification.Name {
    static let watchDemoAction = Notification.Name("WatchDemoAction")
}

private enum DoneTonightTone {
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

private enum DoneTonightCopy {
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
