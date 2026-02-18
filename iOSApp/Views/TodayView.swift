import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var locationMonitor: LocationMonitor
    @State private var didAnimate = false
    @State private var statusDetailsExpanded = false

    private var allPresets: [DrinkPreset] {
        store.quickAddPresets()
    }

    private var hasSessionDrinks: Bool {
        store.sessionSnapshot.totalStandardDrinks > 0.001
    }

    private var isWithinLegalLimit: Bool {
        store.sessionSnapshot.remainingToSaferDrive <= 0
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalInset = max(20, max(proxy.safeAreaInsets.leading, proxy.safeAreaInsets.trailing))
            let contentWidth = max(0, proxy.size.width - (horizontalInset * 2))

            ZStack(alignment: .topLeading) {
                NightBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                            .opacity(didAnimate ? 1 : 0)
                            .offset(y: didAnimate ? 0 : 12)
                            .animation(.easeOut(duration: 0.45), value: didAnimate)

                        if !hasSessionDrinks {
                            kickoffCard
                                .opacity(didAnimate ? 1 : 0)
                                .offset(y: didAnimate ? 0 : 16)
                                .animation(.easeOut(duration: 0.45).delay(0.05), value: didAnimate)
                        }

                        if hasSessionDrinks {
                            statusCard
                                .opacity(didAnimate ? 1 : 0)
                                .offset(y: didAnimate ? 0 : 20)
                                .animation(.spring(response: 0.56, dampingFraction: 0.88).delay(0.08), value: didAnimate)
                        }

                        quickAddCard
                            .opacity(didAnimate ? 1 : 0)
                            .offset(y: didAnimate ? 0 : 20)
                            .animation(.spring(response: 0.56, dampingFraction: 0.88).delay(0.12), value: didAnimate)

                        hydrationCard
                            .opacity(didAnimate ? 1 : 0)
                            .offset(y: didAnimate ? 0 : 20)
                            .animation(.spring(response: 0.56, dampingFraction: 0.88).delay(0.15), value: didAnimate)

                        reminderSection
                            .opacity(didAnimate ? 1 : 0)
                            .offset(y: didAnimate ? 0 : 20)
                            .animation(.spring(response: 0.56, dampingFraction: 0.88).delay(0.18), value: didAnimate)
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.horizontal, horizontalInset)
                    .padding(.top, max(16, proxy.safeAreaInsets.top + 8))
                    .padding(.bottom, max(84, proxy.safeAreaInsets.bottom + 56))
                }
                .frame(width: proxy.size.width, alignment: .leading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .task {
            guard !didAnimate else { return }
            didAnimate = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Round?")
                .font(NightTheme.titleFont)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text("Tonight dashboard")
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

    private var kickoffCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NightTheme.accent)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.16)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Start tonight")
                        .font(NightTheme.sectionFont)
                        .foregroundStyle(.white)

                    Text("Your first log unlocks recovery ETA and hydration guidance.")
                        .font(NightTheme.bodyFont)
                        .foregroundStyle(NightTheme.label)
                }
            }

            Text("No judgment, just clean signal for a safer night out.")
                .font(NightTheme.captionFont)
                .foregroundStyle(NightTheme.labelSoft)
        }
        .glassCard()
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
                    .background(
                        Capsule()
                            .fill(statusBadgeColor.opacity(0.34))
                    )
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
                Text("Back to normal around")
                    .font(NightTheme.captionFont)
                    .foregroundStyle(NightTheme.label)

                Text(DisplayFormatter.eta(store.sessionSnapshot.saferDriveTime))
                    .font(NightTheme.statFont)
                    .foregroundStyle(.white)

                Text(DisplayFormatter.remaining(store.sessionSnapshot.remainingToSaferDrive))
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
                        isWithinLegalLimit ? "Estimate is now at or below local threshold." : "Estimate is still above local threshold.",
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

    private var statusBadgeText: String {
        if isWithinLegalLimit {
            return "Lower risk"
        }
        return store.sessionSnapshot.intoxicationState.title
    }

    private var statusBadgeColor: Color {
        if isWithinLegalLimit {
            return NightTheme.mint
        }

        switch store.sessionSnapshot.intoxicationState {
        case .clear, .light:
            return NightTheme.accentSoft
        case .social, .tipsy:
            return NightTheme.warning
        case .wavy, .high:
            return Color.red.opacity(0.8)
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

    private var quickAddCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick Add")
                    .font(NightTheme.sectionFont)
                    .foregroundStyle(.white)
                Spacer()
                Text("Tap to log")
                    .font(NightTheme.captionFont)
                    .foregroundStyle(NightTheme.label)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 102), spacing: 10)], spacing: 10) {
                ForEach(allPresets) { preset in
                    Button {
                        store.addQuickDrink(preset: preset, location: locationMonitor.currentLocation?.coordinate)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(tint(for: preset.category).opacity(0.24))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: symbol(for: preset.category))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(tint(for: preset.category))
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.white.opacity(0.9))
                            }

                            Text(preset.category.title)
                                .font(NightTheme.bodyFont.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(presetSummary(preset))
                                .font(NightTheme.captionFont)
                                .foregroundStyle(NightTheme.label)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
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
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glassCard()
    }

    private var hydrationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(NightTheme.accentSoft)
                Text("Home Recovery")
                    .font(NightTheme.sectionFont)
                    .foregroundStyle(.white)
            }

            Text("Hydration target tonight: \(DisplayFormatter.volume(store.sessionSnapshot.hydrationPlanMl, unit: store.profile.unitPreference)).")
                .font(NightTheme.bodyFont)
                .foregroundStyle(.white)

            Text(
                store.sessionSnapshot.recommendElectrolytes
                    ? "Electrolytes recommended before sleep for a smoother morning."
                    : "Water-only plan is enough based on current estimate."
            )
            .font(NightTheme.bodyFont)
            .foregroundStyle(store.sessionSnapshot.recommendElectrolytes ? NightTheme.mint : NightTheme.label)
        }
        .glassCard()
    }

    @ViewBuilder
    private var reminderSection: some View {
        if let reminder = store.reminders.last {
            reminderCard(reminder)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Reminder Feed")
                    .font(NightTheme.sectionFont)
                    .foregroundStyle(.white)
                Text("No alerts yet. We only nudge when it helps tonight stay smooth.")
                    .font(NightTheme.bodyFont)
                    .foregroundStyle(NightTheme.label)
            }
            .glassCard()
        }
    }

    private func reminderCard(_ reminder: ReminderEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Latest Reminder")
                    .font(NightTheme.sectionFont)
                    .foregroundStyle(.white)

                Spacer()

                Text(reminderLabel(for: reminder.type))
                    .font(NightTheme.captionFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill((reminder.type == .missedLog ? NightTheme.warning : NightTheme.mint).opacity(0.35))
                    )
            }

            Text(reminder.context)
                .font(NightTheme.bodyFont)
                .foregroundStyle(.white)
        }
        .glassCard()
    }

    private func reminderLabel(for type: ReminderType) -> String {
        switch type {
        case .missedLog:
            return "Missed Log"
        case .homeHydration:
            return "Home Recovery"
        case .morningCheckIn:
            return "Morning Check-In"
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
}
