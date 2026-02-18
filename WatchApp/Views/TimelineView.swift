import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var store: AppStore

    private var sessionEntries: [DrinkEntry] {
        SessionClock.entriesInCurrentSession(store.entries, now: .now)
            .sorted(by: { $0.timestamp > $1.timestamp })
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Timeline")
                    .font(WatchNightTheme.titleFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if sessionEntries.isEmpty {
                    Text("No drinks yet")
                        .font(WatchNightTheme.bodyFont)
                        .foregroundStyle(WatchNightTheme.label)
                        .watchCard()
                } else {
                    ForEach(sessionEntries.prefix(20)) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: symbol(for: entry.category))
                                .font(.caption)
                                .foregroundStyle(WatchNightTheme.accent)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.servingName ?? entry.category.title)
                                    .font(WatchNightTheme.bodyFont)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)

                                Text("\(Int(entry.volumeMl))ml · \(entry.abvPercent, specifier: "%.1f")%")
                                    .font(WatchNightTheme.captionFont)
                                    .foregroundStyle(WatchNightTheme.labelSoft)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.74)

                                Text(entry.timestamp, style: .time)
                                    .font(WatchNightTheme.captionFont)
                                    .foregroundStyle(WatchNightTheme.label)
                            }

                            Spacer(minLength: 4)

                            Text(DisplayFormatter.standardDrinks(entry.standardDrinks))
                                .font(WatchNightTheme.captionFont.weight(.bold))
                                .foregroundStyle(WatchNightTheme.accentSoft)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .watchCard()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
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
}
