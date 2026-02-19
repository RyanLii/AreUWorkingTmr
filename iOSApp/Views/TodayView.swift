import SwiftUI

private struct TodayServingOption: Identifiable, Hashable {
    let id: String
    let name: String
    let volumeMl: Double

    var subtitle: String {
        "\(Int(volumeMl))ml"
    }
}

private struct TodayDrinkDetailTemplate {
    let title: String
    let servings: [TodayServingOption]
    let abvOptions: [Double]
    let supportsManualVolume: Bool
}

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var locationMonitor: LocationMonitor

    @State private var statusDetailsExpanded = false

    @State private var activeCategory: DrinkCategory?
    @State private var selectedServing: TodayServingOption?
    @State private var selectedABV: Double = 5
    @State private var quantity: Int = 1
    @State private var manualVolumeMl: Int = 180

    @State private var showDoneTonightSheet = false
    @State private var hydrationConfirmed = false
    @State private var rideConfirmed = false
    @State private var alarmConfirmed = false

    private var allPresets: [DrinkPreset] {
        store.quickAddPresets()
    }

    private var hasSessionDrinks: Bool {
        store.sessionSnapshot.totalStandardDrinks > 0.001
    }

    private var isWithinLegalLimit: Bool {
        store.sessionSnapshot.remainingToSaferDrive <= 0
    }

    private var isHighRiskState: Bool {
        switch store.sessionSnapshot.intoxicationState {
        case .wavy, .high:
            return true
        default:
            return false
        }
    }

    private var checklistCompletedCount: Int {
        [hydrationConfirmed, rideConfirmed, alarmConfirmed].filter { $0 }.count
    }

    var body: some View {
        AppScreenScaffold {
            header

            if hasSessionDrinks {
                doneTonightCard
            }

            if hasSessionDrinks {
                statusCard
            }

            if store.canUndoLastDrink() {
                undoCard
            }

            quickAddCard
        }
        .sheet(item: $activeCategory) { category in
            detailSheet(for: category)
        }
        .sheet(isPresented: $showDoneTonightSheet) {
            doneTonightSheet
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Are you working tomorrow?")
                .font(NightTheme.titleFont)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            Text("iPhone dashboard")
                .font(NightTheme.subtitleFont)
                .foregroundStyle(NightTheme.accentSoft)

            Text("Log quickly, keep pace, and land tomorrow with less chaos.")
                .font(NightTheme.bodyFont)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Label("Live estimate", systemImage: "waveform.path.ecg")
                Label("Watch first", systemImage: "applewatch")
            }
            .font(NightTheme.captionFont)
            .foregroundStyle(NightTheme.label)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Live Pulse")
                    .font(NightTheme.sectionFont)
                    .foregroundStyle(.white)

                Spacer()

                Text(statusBadgeText)
                    .font(NightTheme.captionFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(statusBadgeColor.opacity(0.34)))
            }

            HStack(spacing: 10) {
                statChip(
                    title: "State",
                    value: store.sessionSnapshot.intoxicationState.title,
                    accent: statusBadgeColor
                )
                statChip(
                    title: "BAC",
                    value: DisplayFormatter.bac(store.sessionSnapshot.estimatedBAC),
                    accent: NightTheme.accentSoft
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Drive lower-risk")
                    .font(NightTheme.captionFont)
                    .foregroundStyle(NightTheme.label)

                Text(driveReadinessText(for: store.sessionSnapshot))
                    .font(NightTheme.statFont)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)

                Text(driveRemainingText(for: store.sessionSnapshot.remainingToSaferDrive))
                    .font(NightTheme.bodyFont)
                    .foregroundStyle(isWithinLegalLimit ? NightTheme.success : NightTheme.warning)

                if !isWithinLegalLimit {
                    ProgressView(value: safetyProgress)
                        .tint(NightTheme.warning)
                }
            }

            Text(nextSafetyMove)
                .font(NightTheme.bodyFont)
                .foregroundStyle(isWithinLegalLimit ? NightTheme.mint : NightTheme.label)

            DisclosureGroup(isExpanded: $statusDetailsExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "Local threshold reference: BAC <= \(legalThresholdText)",
                        systemImage: "gauge.with.dots.needle.33percent"
                    )
                    .font(NightTheme.captionFont)
                    .foregroundStyle(NightTheme.label)

                    Label(
                        isWithinLegalLimit
                            ? "Estimate is now at or below local threshold."
                            : "Estimate is still above local threshold.",
                        systemImage: isWithinLegalLimit ? "checkmark.shield.fill" : "hourglass"
                    )
                    .font(NightTheme.captionFont)
                    .foregroundStyle(isWithinLegalLimit ? NightTheme.success : NightTheme.warning)

                    Text("Estimate only. If unsure, choose a ride.")
                        .font(NightTheme.captionFont)
                        .foregroundStyle(NightTheme.label)
                }
                .padding(.top, 4)
            } label: {
                Text("Detailed status")
                    .font(NightTheme.captionFont)
                    .foregroundStyle(NightTheme.label)
            }
            .tint(NightTheme.accent)
        }
        .glassCard(.high)
    }

    private var undoCard: some View {
        Button {
            _ = store.undoLastDrink()
        } label: {
            Label("Undo Last Drink", systemImage: "arrow.uturn.backward.circle.fill")
                .font(NightTheme.bodyFont.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
                .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var quickAddCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick Add")
                    .font(NightTheme.sectionFont)
                    .foregroundStyle(.white)
                Spacer()
                Text("Tap card for detail")
                    .font(NightTheme.captionFont)
                    .foregroundStyle(NightTheme.label)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 120), spacing: 10),
                    GridItem(.flexible(minimum: 120), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(allPresets) { preset in
                    quickAddTile(preset)
                }
            }
        }
        .glassCard()
    }

    private func quickAddTile(_ preset: DrinkPreset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tint(for: preset.category).opacity(0.24))
                        .frame(width: 28, height: 28)
                    Image(systemName: symbol(for: preset.category))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint(for: preset.category))
                }

                Spacer(minLength: 2)

                Button {
                    addDefaultDrink(preset)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(NightTheme.accentSoft)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quick add default \(preset.category.title)")

            }

            Text(preset.category.title)
                .font(NightTheme.bodyFont.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(presetSummary(preset))
                .font(NightTheme.captionFont)
                .foregroundStyle(NightTheme.label)
                .lineLimit(3)
                .minimumScaleFactor(0.88)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            openDetail(for: preset)
        }
    }

    private var doneTonightCard: some View {
        Button {
            store.markDoneTonight()
            hydrationConfirmed = false
            rideConfirmed = false
            alarmConfirmed = false
            showDoneTonightSheet = true
        } label: {
            HStack {
                Label("I'm Done Tonight", systemImage: "moon.stars.fill")
                    .font(NightTheme.bodyFont.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Landing")
                    .font(NightTheme.captionFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
            }
            .padding(.vertical, 3)
            .glassCard(.high)
        }
        .buttonStyle(.plain)
    }

    private var doneTonightSheet: some View {
        NavigationStack {
            GeometryReader { proxy in
                let horizontalInset = max(16, max(proxy.safeAreaInsets.leading, proxy.safeAreaInsets.trailing) + 8)
                let topInset = max(16, proxy.safeAreaInsets.top + 10)
                let bottomInset = max(24, proxy.safeAreaInsets.bottom + 16)

                ZStack(alignment: .topLeading) {
                    NightBackdrop()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("I'm Done Tonight")
                                .font(NightTheme.titleFont)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(doneTonightSummary)
                                .font(NightTheme.bodyFont)
                                .foregroundStyle(NightTheme.label)
                                .fixedSize(horizontal: false, vertical: true)
                                .glassCard()

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Landing checklist")
                                        .font(NightTheme.sectionFont)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("\(checklistCompletedCount)/3")
                                        .font(NightTheme.bodyFont.weight(.bold))
                                        .foregroundStyle(NightTheme.accentSoft)
                                }

                                doneToggleButton(
                                    title: "Hydrated",
                                    subtitle: "Finish your water target",
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
                                    subtitle: "Alarm + wind down",
                                    icon: "alarm.fill",
                                    confirmed: alarmConfirmed
                                ) {
                                    alarmConfirmed.toggle()
                                }
                            }
                            .glassCard()

                            if isHighRiskState {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Safety mode")
                                        .font(NightTheme.sectionFont)
                                        .foregroundStyle(.white)

                                    Text("Stay with friends, stop logging new drinks, and lock your ride before leaving.")
                                        .font(NightTheme.bodyFont)
                                        .foregroundStyle(NightTheme.label)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .glassCard(.high)
                            }

                            Button {
                                showDoneTonightSheet = false
                            } label: {
                                Label("Close", systemImage: "checkmark.circle.fill")
                                    .font(NightTheme.bodyFont.weight(.bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(NightTheme.accent)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, horizontalInset)
                        .padding(.top, topInset)
                        .padding(.bottom, bottomInset)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showDoneTonightSheet = false
                    }
                    .tint(NightTheme.accent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func doneToggleButton(
        title: String,
        subtitle: String,
        icon: String,
        confirmed: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: confirmed ? "checkmark.circle.fill" : icon)
                    .foregroundStyle(confirmed ? NightTheme.mint : NightTheme.accentSoft)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(NightTheme.bodyFont.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(NightTheme.captionFont)
                        .foregroundStyle(NightTheme.label)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(confirmed ? 0.15 : 0.09))
            )
        }
        .buttonStyle(.plain)
    }

    private func detailSheet(for category: DrinkCategory) -> some View {
        let template = detailTemplate(for: category, region: store.profile.regionStandard)
        let defaultPreset = store.preset(for: category)
        let currentVolume = currentVolumeMl(category: category, defaultPreset: defaultPreset)
        let servingName = selectedServing?.name ?? defaultPreset.name
        let workingPreset = DrinkPreset(
            name: servingName,
            category: category,
            defaultVolumeMl: currentVolume,
            defaultABV: selectedABV
        )

        let projectedSnapshot = store.projectedSnapshot(adding: workingPreset, count: quantity)
        let perDrinkStd = estimatedStandardDrinks(volumeMl: currentVolume, abv: selectedABV)
        let totalStd = perDrinkStd * Double(quantity)

        return NavigationStack {
            GeometryReader { proxy in
                let horizontalInset = max(16, max(proxy.safeAreaInsets.leading, proxy.safeAreaInsets.trailing) + 8)
                let topInset = max(12, proxy.safeAreaInsets.top + 8)
                let bottomInset = max(24, proxy.safeAreaInsets.bottom + 18)

                ZStack(alignment: .topLeading) {
                    NightBackdrop()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                        Text(template.title)
                            .font(NightTheme.titleFont)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .fixedSize(horizontal: false, vertical: true)

                        if template.supportsManualVolume {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Volume")
                                        .font(NightTheme.captionFont)
                                        .foregroundStyle(NightTheme.label)
                                    Spacer()
                                    Text("\(manualVolumeMl)ml")
                                        .font(NightTheme.bodyFont)
                                        .foregroundStyle(.white)
                                }

                                Stepper(value: $manualVolumeMl, in: 20...2000, step: 10) {
                                    EmptyView()
                                }
                                .labelsHidden()
                            }
                            .glassCard()
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Serving")
                                    .font(NightTheme.captionFont)
                                    .foregroundStyle(NightTheme.label)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(template.servings) { option in
                                        Button {
                                            selectedServing = option
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(option.name)
                                                    .font(NightTheme.bodyFont.weight(.semibold))
                                                    .foregroundStyle(.white)
                                                Text(option.subtitle)
                                                    .font(NightTheme.captionFont)
                                                    .foregroundStyle(NightTheme.label)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(option.id == selectedServing?.id ? NightTheme.accent.opacity(0.28) : Color.white.opacity(0.08))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .glassCard()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("ABV")
                                    .font(NightTheme.captionFont)
                                    .foregroundStyle(NightTheme.label)
                                Spacer()
                                Text("\(selectedABV, specifier: "%.1f")%")
                                    .font(NightTheme.bodyFont)
                                    .foregroundStyle(.white)
                            }

                            Slider(value: $selectedABV, in: 0.5...80, step: 0.5)
                                .tint(NightTheme.accent)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(template.abvOptions, id: \.self) { abv in
                                    Button {
                                        selectedABV = abv
                                    } label: {
                                        Text("\(abv, specifier: "%.1f")%")
                                            .font(NightTheme.captionFont)
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 7)
                                            .background(
                                                Capsule()
                                                    .fill(abs(selectedABV - abv) < 0.01 ? NightTheme.accent.opacity(0.34) : Color.white.opacity(0.10))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 8) {
                            Stepper(value: $quantity, in: 1...8) {
                                HStack {
                                    Text("Count")
                                        .font(NightTheme.captionFont)
                                        .foregroundStyle(NightTheme.label)
                                    Spacer()
                                    Text("\(quantity)x")
                                        .font(NightTheme.bodyFont.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                            }

                            Text("Per drink: ~\(perDrinkStd, specifier: "%.2f") std")
                                .font(NightTheme.captionFont)
                                .foregroundStyle(NightTheme.label)

                            Text("This log: ~\(totalStd, specifier: "%.2f") std")
                                .font(NightTheme.captionFont)
                                .foregroundStyle(NightTheme.label)
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Impact Preview")
                                .font(NightTheme.captionFont)
                                .foregroundStyle(NightTheme.label)

                            HStack {
                                Text("Drive lower-risk")
                                    .font(NightTheme.captionFont)
                                    .foregroundStyle(NightTheme.label)
                                Spacer()
                                Text(driveReadinessText(for: projectedSnapshot))
                                    .font(NightTheme.bodyFont.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.82)
                                    .multilineTextAlignment(.trailing)
                            }

                            Text(driveRemainingText(for: projectedSnapshot.remainingToSaferDrive))
                                .font(NightTheme.captionFont)
                                .foregroundStyle(projectedSnapshot.remainingToSaferDrive <= 0 ? NightTheme.mint : NightTheme.warning)

                            if hasSessionDrinks {
                                Text(etaDeltaText(from: store.sessionSnapshot.saferDriveTime, to: projectedSnapshot.saferDriveTime))
                                    .font(NightTheme.captionFont)
                                    .foregroundStyle(NightTheme.label)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("First log sets your baseline estimate tonight.")
                                    .font(NightTheme.captionFont)
                                    .foregroundStyle(NightTheme.label)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Text("Estimate only, not legal advice.")
                                .font(NightTheme.captionFont)
                                .foregroundStyle(NightTheme.label)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .glassCard(.high)

                        Button {
                            store.addQuickDrink(
                                preset: workingPreset,
                                count: quantity,
                                location: locationMonitor.currentLocation?.coordinate
                            )
                            activeCategory = nil
                        } label: {
                            Label("Log \(quantity)x", systemImage: "checkmark.circle.fill")
                                .font(NightTheme.bodyFont.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.84)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(NightTheme.accent)
                                )
                        }
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
                                .font(NightTheme.bodyFont)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.84)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.white.opacity(0.20), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            saveCurrentAsDefault(for: category)
                        } label: {
                            Label("Set As Default", systemImage: "star.fill")
                                .font(NightTheme.bodyFont)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.84)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(NightTheme.mint.opacity(0.55), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)

                        Text("Default: \(presetSummary(defaultPreset))")
                            .font(NightTheme.captionFont)
                            .foregroundStyle(NightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalInset)
                    .padding(.top, topInset)
                    .padding(.bottom, bottomInset)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        activeCategory = nil
                    }
                    .tint(NightTheme.accent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var statusBadgeText: String {
        isWithinLegalLimit ? "Lower risk" : store.sessionSnapshot.intoxicationState.title
    }

    private var statusBadgeColor: Color {
        if isWithinLegalLimit { return NightTheme.mint }
        switch store.sessionSnapshot.intoxicationState {
        case .clear, .light: return NightTheme.accentSoft
        case .social, .tipsy: return NightTheme.warning
        case .wavy, .high: return Color.red.opacity(0.8)
        }
    }

    private var nextSafetyMove: String {
        if isWithinLegalLimit {
            return "Estimate says you're likely back in range. Keep hydrating and wind down."
        }

        switch store.sessionSnapshot.intoxicationState {
        case .clear, .light:
            return "Easy pace. Keep logging each drink for a cleaner ETA."
        case .social:
            return "Add water now to keep tomorrow smoother."
        case .tipsy:
            return "Water + food now. Slow the pace for a better landing."
        case .wavy:
            return "Stop here, lock a ride, and stay with your people."
        case .high:
            return "Safety mode: sit down, hydrate, and get support."
        }
    }

    private var legalThresholdText: String {
        store.profile.regionStandard.legalDriveBACLimitText
    }

    private var safetyProgress: Double {
        let threshold = max(store.profile.regionStandard.legalDriveBACLimit, 0.001)
        let bac = max(store.sessionSnapshot.estimatedBAC, 0)
        return min(max(1 - (bac / (threshold * 2)), 0), 1)
    }

    private var doneTonightSummary: String {
        let eta = DisplayFormatter.eta(store.sessionSnapshot.saferDriveTime)
        if isHighRiskState {
            return "You're currently in a high-risk state. Prioritize water, stay with friends, and avoid driving. Current estimate settles around \(eta)."
        }

        if store.sessionSnapshot.remainingToSaferDrive > 0 {
            return "Good call wrapping up. Current estimate settles around \(eta). Keep water and pace your landing."
        }

        return "Good call wrapping up. You're currently in a lower-risk range; keep hydrating and set yourself up for tomorrow."
    }

    private func statChip(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(NightTheme.captionFont)
                .foregroundStyle(NightTheme.label)
            Text(value)
                .font(NightTheme.bodyFont.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accent.opacity(0.34), lineWidth: 1)
                )
        )
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

    private func addDefaultDrink(_ preset: DrinkPreset) {
        store.addQuickDrink(
            preset: preset,
            location: locationMonitor.currentLocation?.coordinate
        )
    }

    private func openDetail(for preset: DrinkPreset) {
        let template = detailTemplate(for: preset.category, region: store.profile.regionStandard)
        selectedServing = template.servings.first(where: { abs($0.volumeMl - preset.defaultVolumeMl) < 0.1 }) ?? template.servings.first
        selectedABV = preset.defaultABV
        manualVolumeMl = Int(preset.defaultVolumeMl.rounded())
        quantity = 1
        activeCategory = preset.category
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
        case .beer: return Color(red: 0.99, green: 0.79, blue: 0.34)
        case .wine: return Color(red: 0.98, green: 0.52, blue: 0.58)
        case .shot: return Color(red: 0.99, green: 0.56, blue: 0.36)
        case .cocktail: return NightTheme.mint
        case .spirits: return Color(red: 0.99, green: 0.69, blue: 0.37)
        case .custom: return Color.white
        }
    }

    private func detailTemplate(for category: DrinkCategory, region: RegionStandard) -> TodayDrinkDetailTemplate {
        switch category {
        case .beer:
            let servings: [TodayServingOption]
            switch region {
            case .au10g:
                servings = [
                    TodayServingOption(id: "beer_pot", name: "Pot", volumeMl: 285),
                    TodayServingOption(id: "beer_schooner", name: "Schooner", volumeMl: 425),
                    TodayServingOption(id: "beer_pint_au", name: "Pint", volumeMl: 570),
                    TodayServingOption(id: "beer_longneck", name: "Longneck", volumeMl: 750)
                ]
            case .uk8g:
                servings = [
                    TodayServingOption(id: "beer_half_pint", name: "Half Pint", volumeMl: 284),
                    TodayServingOption(id: "beer_pint_uk", name: "Pint", volumeMl: 568),
                    TodayServingOption(id: "beer_can_uk", name: "Can", volumeMl: 440),
                    TodayServingOption(id: "beer_bottle_uk", name: "Bottle", volumeMl: 500)
                ]
            case .us14g:
                servings = [
                    TodayServingOption(id: "beer_can", name: "12oz Can", volumeMl: 355),
                    TodayServingOption(id: "beer_pint_us", name: "16oz Pint", volumeMl: 473),
                    TodayServingOption(id: "beer_tallboy", name: "Tallboy", volumeMl: 473),
                    TodayServingOption(id: "beer_bomber", name: "Bomber", volumeMl: 650)
                ]
            }

            return TodayDrinkDetailTemplate(
                title: "Beer",
                servings: servings,
                abvOptions: [3.5, 4.2, 5.0, 6.0, 7.5, 9.0],
                supportsManualVolume: false
            )

        case .wine:
            let servings: [TodayServingOption]
            switch region {
            case .au10g:
                servings = [
                    TodayServingOption(id: "wine_small_au", name: "Small", volumeMl: 100),
                    TodayServingOption(id: "wine_std_au", name: "Standard", volumeMl: 150),
                    TodayServingOption(id: "wine_large_au", name: "Large", volumeMl: 200),
                    TodayServingOption(id: "wine_bottle_au", name: "Bottle", volumeMl: 750)
                ]
            case .uk8g:
                servings = [
                    TodayServingOption(id: "wine_125", name: "125ml", volumeMl: 125),
                    TodayServingOption(id: "wine_175", name: "175ml", volumeMl: 175),
                    TodayServingOption(id: "wine_250", name: "250ml", volumeMl: 250),
                    TodayServingOption(id: "wine_bottle_uk", name: "Bottle", volumeMl: 750)
                ]
            case .us14g:
                servings = [
                    TodayServingOption(id: "wine_5oz", name: "5oz Pour", volumeMl: 148),
                    TodayServingOption(id: "wine_6oz", name: "6oz Pour", volumeMl: 177),
                    TodayServingOption(id: "wine_9oz", name: "9oz Large", volumeMl: 266),
                    TodayServingOption(id: "wine_bottle_us", name: "Bottle", volumeMl: 750)
                ]
            }

            return TodayDrinkDetailTemplate(
                title: "Wine",
                servings: servings,
                abvOptions: [9.0, 11.0, 12.0, 13.5, 15.0],
                supportsManualVolume: false
            )

        case .shot:
            let servings: [TodayServingOption]
            switch region {
            case .au10g:
                servings = [
                    TodayServingOption(id: "shot_single_au", name: "Single", volumeMl: 30),
                    TodayServingOption(id: "shot_classic_au", name: "Classic", volumeMl: 45),
                    TodayServingOption(id: "shot_double_au", name: "Double", volumeMl: 60)
                ]
            case .uk8g:
                servings = [
                    TodayServingOption(id: "shot_uk_single", name: "Single", volumeMl: 25),
                    TodayServingOption(id: "shot_uk_large", name: "Large", volumeMl: 35),
                    TodayServingOption(id: "shot_uk_double", name: "Double", volumeMl: 50)
                ]
            case .us14g:
                servings = [
                    TodayServingOption(id: "shot_1oz", name: "1oz", volumeMl: 30),
                    TodayServingOption(id: "shot_1_5oz", name: "1.5oz", volumeMl: 44),
                    TodayServingOption(id: "shot_double_us", name: "Double", volumeMl: 60)
                ]
            }

            return TodayDrinkDetailTemplate(
                title: "Shot",
                servings: servings,
                abvOptions: [30.0, 35.0, 40.0, 45.0, 50.0],
                supportsManualVolume: false
            )

        case .cocktail:
            return TodayDrinkDetailTemplate(
                title: "Cocktail",
                servings: [
                    TodayServingOption(id: "cocktail_small", name: "Small", volumeMl: 120),
                    TodayServingOption(id: "cocktail_standard", name: "Standard", volumeMl: 180),
                    TodayServingOption(id: "cocktail_tall", name: "Tall", volumeMl: 250),
                    TodayServingOption(id: "cocktail_jumbo", name: "Jumbo", volumeMl: 330)
                ],
                abvOptions: [8.0, 12.0, 16.0, 20.0, 24.0],
                supportsManualVolume: false
            )

        case .spirits:
            return TodayDrinkDetailTemplate(
                title: "Spirits",
                servings: [
                    TodayServingOption(id: "spirits_nip", name: "Nip", volumeMl: 30),
                    TodayServingOption(id: "spirits_single", name: "Single", volumeMl: 45),
                    TodayServingOption(id: "spirits_double", name: "Double", volumeMl: 60),
                    TodayServingOption(id: "spirits_large", name: "Large", volumeMl: 90)
                ],
                abvOptions: [35.0, 40.0, 45.0, 50.0, 55.0],
                supportsManualVolume: false
            )

        case .custom:
            return TodayDrinkDetailTemplate(
                title: "Custom",
                servings: [],
                abvOptions: [5.0, 8.0, 12.0, 18.0, 30.0, 40.0],
                supportsManualVolume: true
            )
        }
    }
}
