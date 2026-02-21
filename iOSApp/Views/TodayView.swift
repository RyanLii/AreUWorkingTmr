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
    @Environment(\.openURL) private var openURL

    @State private var statusDetailsExpanded = false
    @State private var statusChipPulse = false
    @State private var clearBarSweep: CGFloat = -0.35
    @State private var clearBarSweepActive = false
    @State private var progressAnchorToken: String = ""
    @State private var progressAnchorSessionStart: Date?
    @State private var progressAnchorProjectedZero: Date = .now

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

    private var statusSnapshot: SessionSnapshot {
        store.sessionSnapshot
    }

    private var statusEffectiveStandardDrinks: Double {
        statusSnapshot.effectiveStandardDrinks
    }

    private var statusIsCleared: Bool {
        statusSnapshot.state == .cleared
    }

    private var currentEffectiveStandardDrinks: Double {
        store.sessionSnapshot.effectiveStandardDrinks
    }

    private var buzzStatus: BuzzStatusDescriptor {
        BuzzStatusDescriptor.from(snapshot: statusSnapshot)
    }

    private var isHeavyLoad: Bool {
        currentEffectiveStandardDrinks >= 5 || store.sessionSnapshot.totalStandardDrinks >= 8
    }

    private var checklistCompletedCount: Int {
        [hydrationConfirmed, rideConfirmed, alarmConfirmed].filter { $0 }.count
    }

    var body: some View {
        AppScreenScaffold {
            header

            if hasSessionDrinks && !store.hasMarkedDoneTonight {
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
                Label("Live standard drinks", systemImage: "waveform.path.ecg")
                Label("Watch first", systemImage: "applewatch")
            }
            .font(NightTheme.captionFont)
            .foregroundStyle(NightTheme.label)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status")
                    .font(NightTheme.sectionFont)
                    .foregroundStyle(.white)

                Spacer()

                statusBadgePill
            }

            Text(statusMoodCopy)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(statusBadgeColor.opacity(0.90))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            statusRecoveryBlock

            DisclosureGroup(isExpanded: $statusDetailsExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    statusDetailRow(
                        "Total logged",
                        DisplayFormatter.standardDrinks(statusSnapshot.totalStandardDrinks)
                    )
                    statusDetailRow(
                        "In body now",
                        DisplayFormatter.standardDrinks(statusEffectiveStandardDrinks)
                    )
                    statusDetailRow(
                        "Still absorbing",
                        DisplayFormatter.standardDrinks(statusSnapshot.pendingAbsorptionStandardDrinks)
                    )
                    statusDetailRow(
                        "Metabolized",
                        DisplayFormatter.standardDrinks(statusSnapshot.metabolizedStandardDrinks)
                    )
                    statusDetailRow(
                        "Estimated peak",
                        "\(DisplayFormatter.standardDrinks(statusSnapshot.estimatedPeakStandardDrinks)) at \(DisplayFormatter.eta(statusSnapshot.estimatedPeakTime))"
                    )
                    statusDetailRow(
                        "Feel human",
                        DisplayFormatter.eta(statusSnapshot.projectedRecoveryTime)
                    )
                    statusDetailRow(
                        "Full clear",
                        DisplayFormatter.eta(statusSnapshot.projectedZeroTime)
                    )

                    if statusSnapshot.clearingElapsed > 1,
                       (statusSnapshot.state == .clearing || statusSnapshot.state == .cleared) {
                        statusDetailRow(
                            "Clearing for",
                            DisplayFormatter.duration(statusSnapshot.clearingElapsed)
                        )
                    }

                    Text("Nerd math only. Estimate, not legal or medical advice.")
                        .font(NightTheme.captionFont)
                        .foregroundStyle(NightTheme.label)
                }
                .padding(.top, 4)
            } label: {
                Text("Nerd stuff")
                    .font(NightTheme.captionFont)
                    .foregroundStyle(NightTheme.label)
            }
            .tint(NightTheme.accent)
        }
        .glassCard(.high)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: buzzStatus.level)
        .onAppear {
            syncStableProgressAnchor()
        }
        .onChange(of: statusSnapshot.lastDrinkTime) { _, _ in
            syncStableProgressAnchor()
        }
        .onChange(of: statusSnapshot.totalStandardDrinks) { _, _ in
            syncStableProgressAnchor()
        }
        .onChange(of: statusSnapshot.remainingToZero) { _, _ in
            syncStableProgressAnchor()
        }
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
                            HStack {
                                Spacer()
                                Button("Close") {
                                    showDoneTonightSheet = false
                                }
                                .font(NightTheme.captionFont.weight(.bold))
                                .foregroundStyle(NightTheme.accent)
                            }

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

                                Text("Tap each item to check it off.")
                                    .font(NightTheme.captionFont)
                                    .foregroundStyle(NightTheme.label)

                                doneToggleButton(
                                    title: "Hydrated",
                                    subtitle: "Finish your water target",
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
                                    subtitle: "Alarm + wind down",
                                    icon: "alarm.fill",
                                    confirmed: alarmConfirmed
                                ) {
                                    alarmConfirmed.toggle()
                                }
                            }
                            .glassCard()

                            Button {
                                sendBuddyText()
                            } label: {
                                Label("Text Mate", systemImage: "message.fill")
                                    .font(NightTheme.bodyFont.weight(.semibold))
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
                                                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)

                            if isHeavyLoad {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Recovery mode")
                                        .font(NightTheme.sectionFont)
                                        .foregroundStyle(.white)

                                    Text("Big night logged. Switch to water, light food, and rest.")
                                        .font(NightTheme.bodyFont)
                                        .foregroundStyle(NightTheme.label)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .glassCard(.high)
                            }

                            Button {
                                store.markDoneTonight()
                                showDoneTonightSheet = false
                            } label: {
                                Label("Done", systemImage: "checkmark.circle.fill")
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
                Image(systemName: icon)
                    .foregroundStyle(confirmed ? NightTheme.mint : NightTheme.accentSoft)
                    .frame(width: 16)

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

                Image(systemName: confirmed ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(confirmed ? NightTheme.mint : NightTheme.labelSoft)
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
                                        .contentShape(Rectangle())
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
                            Label("Log Saved Default", systemImage: "bolt.fill")
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
                            Label("Save Current as Default", systemImage: "star.fill")
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
            .onAppear {
                seedDetailState(for: category, resetQuantity: false)
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

    private var statusBadgePill: some View {
        Text(buzzStatus.title)
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: Color.black.opacity(0.42), radius: 1, x: 0, y: 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
            .shadow(color: statusBadgeColor.opacity(statusChipPulse ? 0.56 : 0.30), radius: statusChipPulse ? 14 : 8, y: 2)
            .scaleEffect(statusChipPulse ? 1.02 : 1.0)
            .onAppear {
                startStatusChipPulseIfNeeded()
            }
    }

    private var statusRecoveryBlock: some View {
        Group {
            if !statusIsCleared && statusSnapshot.remainingToZero > 0 {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let cooledProgress = dynamicCooledOffProgress(at: context.date)
                    let recoveryFraction = dynamicRecoveryFraction()
                    VStack(alignment: .leading, spacing: 6) {
                        remainingLoadBar(progress: cooledProgress, recoveryFraction: recoveryFraction)
                        HStack {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(NightTheme.warning)
                                    .frame(width: 6, height: 6)
                                Text("Feel human \(DisplayFormatter.eta(statusSnapshot.projectedRecoveryTime))")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(NightTheme.warning.opacity(0.9))
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Text("Full clear \(DisplayFormatter.eta(displayProjectedZeroTime))")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(NightTheme.label)
                                Circle()
                                    .fill(Color(red: 0.36, green: 0.76, blue: 0.92))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        Text("Model estimate only — actual recovery varies by person. Not medical or legal advice.")
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundStyle(NightTheme.label.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .transition(.identity)
            }
        }
    }

    private var statusBadgeColor: Color {
        switch buzzStatus.level {
        case .underTheRadar:
            return NightTheme.mint
        case .goodVibes:
            return Color(red: 0.76, green: 0.91, blue: 0.52)
        case .buzzin:
            return NightTheme.accentSoft
        case .wavy:
            return NightTheme.warning
        case .onFire:
            return Color(red: 0.98, green: 0.48, blue: 0.23)
        case .tooLit:
            return Color(red: 0.95, green: 0.30, blue: 0.24)
        case .takeItEasyZone:
            return Color(red: 0.78, green: 0.18, blue: 0.20)
        }
    }

    private var statusMoodCopy: String {
        if statusSnapshot.state == .clearing && !statusIsCleared {
            return "\(buzzStatus.description) Cooling off now."
        }

        return buzzStatus.description
    }

    private var statusRecoveryHeadline: String {
        if statusIsCleared {
            return "You are all good now."
        }

        return "Feeling better around \(DisplayFormatter.eta(statusSnapshot.projectedRecoveryTime))."
    }

    private var statusRecoveryCountdown: String {
        if statusIsCleared {
            return "All good"
        }

        let remaining = max(0, statusSnapshot.projectedRecoveryTime.timeIntervalSince(.now))
        return DisplayFormatter.countdown(remaining)
    }

    private func dynamicRemainingToZero(at now: Date) -> TimeInterval {
        if !progressAnchorToken.isEmpty {
            return max(0, progressAnchorProjectedZero.timeIntervalSince(now))
        }

        let elapsed = max(0, now.timeIntervalSince(statusSnapshot.date))
        return max(0, statusSnapshot.remainingToZero - elapsed)
    }

    private func dynamicCooledOffProgress(at now: Date) -> Double {
        let start = progressAnchorSessionStart
            ?? currentSessionFirstDrinkTime
            ?? statusSnapshot.lastDrinkTime
            ?? statusSnapshot.date
        let end = !progressAnchorToken.isEmpty ? progressAnchorProjectedZero : statusSnapshot.projectedZeroTime
        let total = end.timeIntervalSince(start)
        guard total > 1 else { return statusIsCleared ? 1 : 0 }
        return min(max(now.timeIntervalSince(start) / total, 0), 1)
    }

    private func dynamicRecoveryFraction() -> Double {
        let start = progressAnchorSessionStart
            ?? currentSessionFirstDrinkTime
            ?? statusSnapshot.lastDrinkTime
            ?? statusSnapshot.date
        let end = !progressAnchorToken.isEmpty ? progressAnchorProjectedZero : statusSnapshot.projectedZeroTime
        let total = end.timeIntervalSince(start)
        guard total > 1 else { return 0.85 }
        return min(max(statusSnapshot.projectedRecoveryTime.timeIntervalSince(start) / total, 0), 1)
    }

    private func cooldownFlavorCopy(progress: Double) -> String {
        if progress > 0.75 {
            return "Still pretty up there. Sip water and pace it."
        }

        if progress > 0.45 {
            return "Cruisin' now. Keep it steady, mate."
        }

        if progress > 0.20 {
            return "Winding down. Nearly back to normal."
        }

        return "Home stretch. You are almost all good."
    }

    private func remainingLoadBar(progress: Double, recoveryFraction: Double) -> some View {
        let barHeight: CGFloat = 20
        let runnerSize: CGFloat = barHeight

        return GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            let totalWidth = proxy.size.width
            let width = max(0, totalWidth * clamped)
            let recoveryX = max(0, min(totalWidth * min(max(recoveryFraction, 0), 1), totalWidth))
            let glowWidth = max(22, width * 0.24)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: barHeight)

                if width > 0 {
                    let recoveryStop = min(max(recoveryX / width, 0), 1)

                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: NightTheme.mint.opacity(0.95), location: 0),
                                        .init(color: NightTheme.warning.opacity(0.88), location: recoveryStop),
                                        .init(color: Color(red: 0.20, green: 0.60, blue: 0.95), location: min(recoveryStop + 0.001, 1)),
                                        .init(color: Color(red: 0.40, green: 0.82, blue: 1.00), location: 1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.02),
                                        Color.white.opacity(0.36),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: glowWidth, height: barHeight)
                            .offset(x: (width + glowWidth) * clearBarSweep - glowWidth)
                            .blendMode(.screen)
                    }
                    .frame(width: width, height: barHeight)
                    .clipShape(Capsule())
                    .animation(.linear(duration: 0.5), value: clamped)

                    LottieView(animationName: "Running character")
                        .frame(width: runnerSize, height: runnerSize)
                        .offset(x: max(0, width - runnerSize))
                        .animation(.linear(duration: 0.5), value: clamped)
                }

                if recoveryX > 6 && recoveryX < totalWidth - 6 {
                    Rectangle()
                        .fill(Color.white.opacity(0.65))
                        .frame(width: 1.5, height: barHeight - 4)
                        .offset(x: recoveryX - 0.75)
                }
            }
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
            .onAppear {
                startClearBarSweepIfNeeded()
            }
        }
        .frame(height: barHeight)
    }

    private func startStatusChipPulseIfNeeded() {
        guard !statusChipPulse else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            statusChipPulse = true
        }
    }

    private func startClearBarSweepIfNeeded() {
        guard !clearBarSweepActive else { return }
        clearBarSweepActive = true
        clearBarSweep = -0.35
        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
            clearBarSweep = 1.2
        }
    }

    private var progressSessionToken: String {
        let lastDrinkEpoch = Int(statusSnapshot.lastDrinkTime?.timeIntervalSince1970 ?? 0)
        let totalBucket = Int((statusSnapshot.totalStandardDrinks * 1000).rounded())
        return "\(lastDrinkEpoch)-\(totalBucket)"
    }

    private var currentSessionFirstDrinkTime: Date? {
        let session = SessionClock.entriesInCurrentSession(store.entries, now: .now, calendar: .current)
        return session.map(\.timestamp).min()
    }

    private var displayProjectedZeroTime: Date {
        let reference = !progressAnchorToken.isEmpty ? progressAnchorProjectedZero : statusSnapshot.projectedZeroTime
        let roundedMinute = floor(reference.timeIntervalSince1970 / 60) * 60
        return Date(timeIntervalSince1970: roundedMinute)
    }

    private func syncStableProgressAnchor() {
        if statusSnapshot.totalStandardDrinks <= 0 || statusSnapshot.state == .cleared {
            progressAnchorToken = ""
            progressAnchorSessionStart = nil
            progressAnchorProjectedZero = statusSnapshot.projectedZeroTime
            return
        }

        let token = progressSessionToken
        guard token != progressAnchorToken else { return }

        progressAnchorToken = token
        progressAnchorSessionStart = currentSessionFirstDrinkTime
            ?? statusSnapshot.lastDrinkTime
            ?? statusSnapshot.date
        progressAnchorProjectedZero = statusSnapshot.projectedZeroTime
    }

    private var doneTonightSummary: String {
        let baselineTime = DisplayFormatter.eta(store.sessionSnapshot.projectedZeroTime)
        let liveAmount = DisplayFormatter.standardDrinks(currentEffectiveStandardDrinks)

        if isHeavyLoad {
            return "Big night logged. About \(liveAmount) is still active. Switch to water and rest. Baseline trends around \(baselineTime)."
        }

        if store.sessionSnapshot.remainingToZero > 0 {
            return "Good call wrapping up. About \(liveAmount) is still active. Baseline trends around \(baselineTime)."
        }

        return "Good call wrapping up. You're near baseline now. Hydrate and set yourself up for tomorrow."
    }

    private func statusDetailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(NightTheme.captionFont)
                .foregroundStyle(NightTheme.label)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(value)
                .font(NightTheme.captionFont.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
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

    private func addDefaultDrink(_ preset: DrinkPreset) {
        store.addQuickDrink(
            preset: preset,
            location: locationMonitor.currentLocation?.coordinate
        )
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

    private func openDetail(for preset: DrinkPreset) {
        seedDetailState(for: preset.category, preset: preset, resetQuantity: true)
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
