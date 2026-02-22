import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.editMode) private var editMode

    private var sortedEntries: [DrinkEntry] {
        SessionClock.entriesInCurrentSession(store.entries, now: .now)
            .sorted(by: { $0.timestamp > $1.timestamp })
    }

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    var body: some View {
        AppScreenScaffold {
            if sortedEntries.isEmpty {
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
                        ForEach(sortedEntries) { entry in
                            entryRow(entry)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("History")
                    .font(NightTheme.sectionFont.weight(.bold))
                    .foregroundStyle(.white)
            }

            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .tint(NightTheme.accent)
            }
        }
    }

    private func entryRow(_ entry: DrinkEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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

                Spacer(minLength: 8)

                Text(DisplayFormatter.standardDrinks(entry.standardDrinks))
                    .font(NightTheme.bodyFont.weight(.semibold))
                    .foregroundStyle(NightTheme.accentSoft)
            }

            if isEditing {
                Button(role: .destructive) {
                    store.deleteEntries(ids: Set([entry.id]))
                } label: {
                    Label("Delete log", systemImage: "trash")
                        .font(NightTheme.captionFont.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(NightTheme.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
