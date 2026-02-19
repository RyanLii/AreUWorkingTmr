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
        state: .clear,
        workingTomorrow: false
    )
    @State private var detailScrollToBottomToken = 0

    private var presets: [DrinkPreset] {
        store.quickAddPresets()
    }

    private var checklistCompletedCount: Int {
        [hydrationConfirmed, rideConfirmed, alarmConfirmed].filter { $0 }.count
    }

    private var hasSessionDrinks: Bool {
        store.sessionSnapshot.totalStandardDrinks > 0.001
    }

    private var isHighRiskState: Bool {
        switch store.sessionSnapshot.intoxicationState {
        case .wavy, .high:
            return true
        default:
            return false
        }
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

                if hasSessionDrinks {
                    Button {
                        store.markDoneTonight()
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

                            Spacer(minLength: 6)

                            Image(systemName: "chevron.right.circle.fill")
                                .foregroundStyle(WatchNightTheme.accentSoft)
                        }
                        .watchCard()
                    }
                    .buttonStyle(.plain)
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
                store.markDoneTonight()
                showDoneTonightSheet = true
            default:
                break
            }
        }
    }

    private var quickSessionStatusCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Current state")
                    .font(WatchNightTheme.captionFont)
                    .foregroundStyle(WatchNightTheme.labelSoft)
                Spacer()
                Text(statusBadgeText)
                    .font(WatchNightTheme.captionFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(statusBadgeColor.opacity(0.36))
                    )
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Drive lower-risk")
                    .font(WatchNightTheme.captionFont)
                    .foregroundStyle(WatchNightTheme.labelSoft)
                Spacer(minLength: 8)
                Text(driveReadinessText(for: store.sessionSnapshot))
                    .font(WatchNightTheme.bodyStrong)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.trailing)
            }

            Text(driveRemainingText(for: store.sessionSnapshot.remainingToSaferDrive))
                .font(WatchNightTheme.bodyFont)
                .foregroundStyle(store.sessionSnapshot.remainingToSaferDrive <= 0 ? WatchNightTheme.mint : WatchNightTheme.warning)

            if store.sessionSnapshot.remainingToSaferDrive > 0 {
                ProgressView(value: safetyProgress)
                    .tint(WatchNightTheme.warning)
            }

            Text(nextSafetyMove)
                .font(WatchNightTheme.captionFont)
                .foregroundStyle(isHighRiskState ? WatchNightTheme.warning : WatchNightTheme.label)
                .fixedSize(horizontal: false, vertical: true)

            Text("Estimate only. If unsure, choose a ride.")
                .font(WatchNightTheme.captionFont)
                .foregroundStyle(WatchNightTheme.labelSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .watchCard(highlighted: true)
    }

    private var statusBadgeText: String {
        if store.sessionSnapshot.remainingToSaferDrive <= 0 {
            return "Lower risk"
        }
        return store.sessionSnapshot.intoxicationState.title
    }

    private var statusBadgeColor: Color {
        if store.sessionSnapshot.remainingToSaferDrive <= 0 {
            return WatchNightTheme.mint
        }

        switch store.sessionSnapshot.intoxicationState {
        case .clear, .light:
            return WatchNightTheme.accentSoft
        case .social, .tipsy:
            return WatchNightTheme.warning
        case .wavy, .high:
            return WatchNightTheme.danger
        }
    }

    private var safetyProgress: Double {
        let threshold = max(store.profile.regionStandard.legalDriveBACLimit, 0.001)
        let bac = max(store.sessionSnapshot.estimatedBAC, 0)
        return min(max(1 - (bac / (threshold * 2)), 0), 1)
    }

    private var doneTonightSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
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

                    doneToggleButton(
                        title: "Hydrated",
                        subtitle: "Finish water target",
                        icon: "drop.fill",
                        confirmed: hydrationConfirmed
                    ) {
                        hydrationConfirmed.toggle()
                    }

                    doneToggleButton(
                        title: "Ride sorted",
                        subtitle: "No driving tonight",
                        icon: "car.fill",
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

                if isHighRiskState {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Safety mode")
                            .font(WatchNightTheme.bodyStrong)
                            .foregroundStyle(.white)

                        Text("Stay with friends, skip extra rounds, and sort your ride before leaving.")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)

                        Button {
                            rideConfirmed = true
                        } label: {
                            Label("Mark ride sorted", systemImage: "car.rear.fill")
                                .font(WatchNightTheme.bodyFont)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .foregroundStyle(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.16))
                                )
                        }
                        .buttonStyle(.plain)

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

    private var nextSafetyMove: String {
        if store.sessionSnapshot.remainingToSaferDrive <= 0 {
            return "Estimate says you're likely back in range. Keep hydrating and wind down."
        }

        switch store.sessionSnapshot.intoxicationState {
        case .clear, .light:
            return "Easy pace. Keep logging each drink for a clearer recovery time."
        case .social:
            return "Add some water now to keep tomorrow smooth."
        case .tipsy:
            return "Water + food now. Slow down and recover."
        case .wavy:
            return "Stop here, lock a ride, and stay with your people."
        case .high:
            return "Safety first. Sit down, hydrate, and get support."
        }
    }

    private var doneTonightContext: String {
        let label = DoneTonightCopy.toneLabel(
            totalStandardDrinks: store.sessionSnapshot.totalStandardDrinks,
            state: store.sessionSnapshot.intoxicationState,
            workingTomorrow: store.effectiveWorkingTomorrow
        )
        return "\(store.sessionSnapshot.intoxicationState.recoveryHint) - \(label)"
    }

    private func refreshDoneTonightMessage() {
        doneTonightMessage = DoneTonightCopy.random(
            totalStandardDrinks: store.sessionSnapshot.totalStandardDrinks,
            state: store.sessionSnapshot.intoxicationState,
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
        let previewPreset = DrinkPreset(
            name: selectedServing?.name ?? category.title,
            category: category,
            defaultVolumeMl: selectedVolume,
            defaultABV: selectedABV
        )
        let projectedSnapshot = store.projectedSnapshot(adding: previewPreset, count: quantity)

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

                VStack(alignment: .leading, spacing: 5) {
                    Text("Impact Preview")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.label)

                    HStack {
                        Text("Drive lower-risk")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)
                        Spacer()
                        Text(driveReadinessText(for: projectedSnapshot))
                            .font(WatchNightTheme.bodyFont)
                            .foregroundStyle(.white)
                    }

                    Text(driveRemainingText(for: projectedSnapshot.remainingToSaferDrive))
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(projectedSnapshot.remainingToSaferDrive <= 0 ? WatchNightTheme.mint : WatchNightTheme.warning)

                    if hasSessionDrinks {
                        Text(etaDeltaText(from: store.sessionSnapshot.saferDriveTime, to: projectedSnapshot.saferDriveTime))
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)
                    } else {
                        Text("First log sets your baseline estimate tonight.")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.label)
                    }

                    Text("Estimate only, not legal advice.")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.label)
                }
                .watchCard(highlighted: true)

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
                    Label("Use Default", systemImage: "bolt.fill")
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
                    Label("Set As Default", systemImage: "star.fill")
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
        }
        .presentationDetents([.medium, .large])
    }

    private func etaDeltaText(from baseline: Date, to projected: Date) -> String {
        let seconds = max(0, Int(projected.timeIntervalSince(baseline)))
        guard seconds > 60 else {
            return "Logging this keeps ETA about the same."
        }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours == 0 {
            return "Adds around \(minutes)m to your estimate."
        }

        return "Adds around \(hours)h \(minutes)m to your estimate."
    }

    private func driveReadinessText(for snapshot: SessionSnapshot) -> String {
        if snapshot.remainingToSaferDrive <= 0 {
            return "Likely under local limit now"
        }
        return DisplayFormatter.eta(snapshot.saferDriveTime)
    }

    private func driveRemainingText(for interval: TimeInterval) -> String {
        if interval <= 0 {
            return "No wait estimated"
        }
        return DisplayFormatter.remaining(interval)
    }

    private func openDetail(for preset: DrinkPreset) {
        let template = detailTemplate(for: preset.category, region: store.profile.regionStandard)
        selectedServing = template.servings.first(where: { abs($0.volumeMl - preset.defaultVolumeMl) < 0.1 }) ?? template.servings.first
        selectedABV = preset.defaultABV
        manualVolumeMl = Int(preset.defaultVolumeMl.rounded())
        quantity = 1
        activeCategory = preset.category
    }

    private func logSelection(for category: DrinkCategory) {
        let volume = currentVolumeMl(category: category, defaultPreset: store.preset(for: category))
        let servingName = selectedServing?.name ?? category.title

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
    case protectMode

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
        case .protectMode:
            return "Protect mode"
        }
    }
}

private enum DoneTonightCopy {
    static func random(totalStandardDrinks: Double, state: IntoxicationState, workingTomorrow _: Bool) -> String {
        let tone = toneBand(totalStandardDrinks: totalStandardDrinks, state: state)
        let candidates = lines(for: tone)
        return candidates.randomElement() ?? "Great night. Hydrate and rest well."
    }

    static func toneLabel(totalStandardDrinks: Double, state: IntoxicationState, workingTomorrow _: Bool) -> String {
        toneBand(totalStandardDrinks: totalStandardDrinks, state: state).label
    }

    private static func toneBand(totalStandardDrinks: Double, state: IntoxicationState) -> DoneTonightTone {
        switch state {
        case .high:
            return .protectMode
        case .wavy:
            return .chaosMode
        default:
            break
        }

        switch totalStandardDrinks {
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
            return .protectMode
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
        case .protectMode:
            return protectMode
        }
    }

    private static func workingTomorrowLines(for tone: DoneTonightTone) -> [String] {
        switch tone {
        case .softStart:
            return [
                "Tomorrow-you is already thanking tonight-you.",
                "Short night, sharp morning. Nice combo.",
                "You kept enough battery for tomorrow's meetings.",
                "Clean finish. Tomorrow stays smooth.",
                "This stop timing protects your morning brain."
            ]
        case .goodVibe:
            return [
                "Great night, still enough fuel for tomorrow.",
                "Hydrate now and tomorrow stays very workable.",
                "You nailed the fun-to-function balance.",
                "This is the exact lane for a good work morning.",
                "You kept the vibe and your calendar intact."
            ]
        case .playfulMode:
            return [
                "Fun delivered. Now set alarm and lock water.",
                "Your future coffee break just got less dramatic.",
                "You can still save tomorrow with one smart finish.",
                "Hydrate hard, sleep early, conquer tomorrow.",
                "This is the last safe exit before work-mode pain."
            ]
        case .spicyMode:
            return [
                "You got your stories. Now rescue tomorrow.",
                "No bonus rounds. Your morning is on the line.",
                "Hydration and sleep are now part of your job prep.",
                "Tonight was loud. Keep tomorrow functional.",
                "One smart stop now can still protect work-you."
            ]
        case .chaosMode:
            return [
                "Work tomorrow means safety mode immediately.",
                "Tonight is done. Water, ride, sleep. In that order.",
                "No more alcohol. Save tomorrow if you can.",
                "Call it now so tomorrow has a chance.",
                "Protect your commute by ending right here."
            ]
        case .protectMode:
            return [
                "Tomorrow can wait. Safety cannot.",
                "Skip work worries. Get home safe first.",
                "Your only task now is safe recovery.",
                "If needed, ask for help now. That is the right move.",
                "Safety first tonight, decisions tomorrow."
            ]
        }
    }

    private static let softStart: [String] = [
        "One drink in and still poetic about life.",
        "Early stop. Elite decision making.",
        "Tiny buzz, big wisdom.",
        "Life is short. This was the right chapter.",
        "You kept it light and lovely tonight.",
        "You clocked out before the plot twist.",
        "This is how calm legends end a night.",
        "One and done has serious style.",
        "Perfect landing. No chaos required.",
        "A gentle finish is still a flex.",
        "You chose vibe over drama. Respect.",
        "This might be the cleanest stop on earth.",
        "Future-you just smiled.",
        "You kept tonight sweet and simple.",
        "Early wrap. Tomorrow stays bright.",
        "You ended while everything still felt golden.",
        "That was enough to make memories.",
        "Small sip energy. Big brain energy.",
        "Nice call. Soft morning unlocked.",
        "This stop timing is chef's kiss.",
        "You kept it classy and kind to yourself.",
        "One drink and already a masterclass in pacing."
    ]

    private static let goodVibe: [String] = [
        "Great vibe, great timing, great exit.",
        "You rode the fun wave and got off perfectly.",
        "This is the sweet spot zone.",
        "Good mood secured. Risk stays low.",
        "You chose the exact right ending scene.",
        "Yes to fun, yes to tomorrow.",
        "You're pacing like a pro tonight.",
        "Solid session. Cleaner finish.",
        "You're in that golden middle lane.",
        "Good energy in, no regret out.",
        "You made this night very winnable.",
        "Confident stop. Beautiful work.",
        "You kept the party and your peace.",
        "Tonight is memorable for the right reasons.",
        "You landed this one with style.",
        "Your future breakfast thanks you.",
        "Hydrate now, brag tomorrow.",
        "Clean finish, steady heart, better sleep.",
        "This is your signature move now.",
        "A little water and you're unstoppable.",
        "You ended before the night got loud.",
        "Excellent cut. Nothing to prove tonight."
    ]

    private static let playfulMode: [String] = [
        "Okay, now we are in stories-for-brunch territory.",
        "Fun level high. Decision quality still online.",
        "That was a smart place to put the full stop.",
        "You had your arc. Time for hydration credits.",
        "Your vibe is loud, your stop is smarter.",
        "You are ending on the strong episode.",
        "We keep the memories, not the headache.",
        "Tonight was spicy enough. Great cutoff.",
        "This is where cool people switch to water.",
        "You can still text with full sentences. Nice.",
        "Great timing. The chaos draft is canceled.",
        "You are steering this night, not chasing it.",
        "This is a power move disguised as chill.",
        "Perfect time to retire from bad ideas.",
        "Hydrate now and tomorrow stays friendly.",
        "You ended before the random side quest.",
        "This stop might save your morning soul.",
        "Call it now and keep the crown.",
        "Enough sparkle for one night. Well played.",
        "Your balance game is very strong.",
        "This is where legends order water without shame.",
        "Fun complete. System recommends cozy mode."
    ]

    private static let spicyMode: [String] = [
        "Alright captain, this was ambitious and iconic.",
        "Night was wild. Your stop is wiser.",
        "You did enough for two plotlines tonight.",
        "This is the exact second to end on a win.",
        "That escalated quickly. Great moment to tap out.",
        "Respectfully: no bonus rounds needed.",
        "You're funny right now. Stay safe right now too.",
        "Tonight has peak content already.",
        "You are in bold mode. We now choose smart mode.",
        "Hydrate like it is your part-time job.",
        "The meme version of you is loud. Sober-you is still in charge.",
        "Good stop. Keep the legend, skip the damage.",
        "No hero driving. Let someone sober do the wheels.",
        "The room is spinning? The app says sit and sip water.",
        "You're at the edge. Great choice to stop here.",
        "You've unlocked premium hydration advice.",
        "Wrap it now and tomorrow remains negotiable.",
        "This is where mature chaos ends beautifully.",
        "Your night is maxed. Recovery starts now.",
        "You are one great decision away from a decent morning.",
        "That was a lot. Ending now is elite.",
        "You gave enough to tonight. Save some for tomorrow."
    ]

    private static let chaosMode: [String] = [
        "Okay this is officially a lot of standard drinks.",
        "Tonight is legendary. Your mission now is safe landing.",
        "No more drinks. Water is the main character now.",
        "You're in chaos mode, so we switch to care mode.",
        "This is not a driving night under any storyline.",
        "Big night confirmed. Soft exit required.",
        "You are funny, loud, and now done for tonight.",
        "Call a ride. Sit down. Hydrate. Repeat.",
        "You won the fun. Do not lose the ending.",
        "The best joke now is waking up okay tomorrow.",
        "Tonight has enough content for three group chats.",
        "Your future self requests immediate water support.",
        "Keep your friends close and your electrolytes closer.",
        "This is where we protect the main character.",
        "No hero moves. No driving. No extra rounds.",
        "You have reached boss-level night. Time to close it.",
        "Legendary attendance. Immediate recovery protocol.",
        "You can still make this a great ending. Start now."
    ]

    private static let protectMode: [String] = [
        "This is ultra high territory. Safety first, always.",
        "Serious level reached. Please stay with trusted people.",
        "No more alcohol tonight. Water and rest only.",
        "You are beyond spicy. We are fully in protect mode.",
        "Please do not travel alone right now.",
        "This is a high-risk zone. Sit, breathe, hydrate.",
        "You need a safe ride and a safe place now.",
        "No driving tonight. Not even close.",
        "You're not in trouble. You just need extra care now.",
        "Your one job now: get home safe with support.",
        "Message a friend and stick together.",
        "Water in small sips. Slow and steady.",
        "If you feel unwell, ask for help immediately.",
        "Huge night. Gentle ending. Stay protected.",
        "Let's make sure tomorrow still happens smoothly.",
        "Tonight stops here. Safety is the flex now.",
        "You can be legendary and careful at the same time.",
        "Main mission: safe home, hydration, sleep."
    ]
}
