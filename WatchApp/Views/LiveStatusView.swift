import SwiftUI

struct LiveStatusView: View {
    @EnvironmentObject private var store: AppStore

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
                    Text(store.sessionSnapshot.intoxicationState.title)
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(stateChipColor.opacity(0.34))
                        )
                }

                VStack(spacing: 6) {
                    metricRow("State", store.sessionSnapshot.intoxicationState.title)
                    metricRow("BAC", String(format: "%.3f", store.sessionSnapshot.estimatedBAC))
                    metricRow("Drive lower-risk", driveReadinessText(for: store.sessionSnapshot))
                }
                .watchCard(highlighted: true)

                Text(driveRemainingText(for: store.sessionSnapshot.remainingToSaferDrive))
                    .font(WatchNightTheme.bodyFont)
                    .foregroundStyle(store.sessionSnapshot.remainingToSaferDrive <= 0 ? WatchNightTheme.mint : WatchNightTheme.warning)

                if store.sessionSnapshot.remainingToSaferDrive > 0 {
                    ProgressView(value: safetyProgress)
                        .tint(WatchNightTheme.warning)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Detailed status")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.labelSoft)

                    Text("Local reference: BAC <= \(store.profile.regionStandard.legalDriveBACLimitText)")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.label)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Estimate only. If unsure, choose a ride.")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .watchCard()

                Text("Hydration \(DisplayFormatter.volume(store.sessionSnapshot.hydrationPlanMl, unit: store.profile.unitPreference))")
                    .font(WatchNightTheme.captionFont)
                    .foregroundStyle(WatchNightTheme.label)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
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
    }

    private var stateChipColor: Color {
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
}
