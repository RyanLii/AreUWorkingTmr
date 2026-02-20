import SwiftUI

struct LiveStatusView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showDetails = false

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
                    Text(store.sessionSnapshot.state.title)
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
                        "Time to clear",
                        isCleared ? "Cleared" : DisplayFormatter.remaining(store.sessionSnapshot.remainingToZero)
                    )
                    metricRow(
                        "Estimated clear time",
                        isCleared ? "Now" : DisplayFormatter.eta(store.sessionSnapshot.projectedZeroTime)
                    )
                    metricRow("Current SD in body", DisplayFormatter.standardDrinks(currentEffectiveStandardDrinks))
                    metricRow("Pending absorption SD", DisplayFormatter.standardDrinks(store.sessionSnapshot.pendingAbsorptionStandardDrinks))
                }
                .watchCard(highlighted: true)

                Text(store.sessionSnapshot.state.supportiveCopy)
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
                        Text("Model details")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.labelSoft)

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

                        Text("Represents modeled final clearing of effective standard drinks only.")
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
        switch store.sessionSnapshot.state {
        case .preAbsorption:
            return WatchNightTheme.accentSoft
        case .absorbing:
            return WatchNightTheme.warning
        case .clearing:
            return WatchNightTheme.mint
        case .cleared:
            return WatchNightTheme.mint
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
