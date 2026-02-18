import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            AppScreenScaffold {
                ScreenIntroCard(
                    title: "Session Timeline",
                    subtitle: "Track each log and clean up anything accidental."
                )

                if store.entries.isEmpty {
                    SectionCard("Timeline") {
                        Text("No drinks logged yet")
                            .font(NightTheme.sectionFont)
                            .foregroundStyle(.white)
                        Text("Your timeline appears here after your first quick add or voice log.")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(NightTheme.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    SectionCard("Timeline") {
                        VStack(spacing: 10) {
                            ForEach(store.entries.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                EditButton()
                    .tint(NightTheme.accent)
            }
        }
    }

    private func entryRow(_ entry: DrinkEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.servingName ?? entry.category.title)
                    .font(NightTheme.sectionFont)
                    .foregroundStyle(.white)

                Text("\(entry.category.title) · \(Int(entry.volumeMl))ml · \(entry.abvPercent, specifier: "%.1f")%")
                    .font(NightTheme.bodyFont)
                    .foregroundStyle(NightTheme.label)
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.timestamp, style: .time)
                    .font(NightTheme.captionFont)
                    .foregroundStyle(NightTheme.labelSoft)
            }

            Spacer()

            Text(DisplayFormatter.standardDrinks(entry.standardDrinks))
                .font(NightTheme.bodyFont.weight(.semibold))
                .foregroundStyle(NightTheme.accentSoft)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
