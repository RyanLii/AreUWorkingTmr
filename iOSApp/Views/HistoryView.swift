import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.editMode) private var editMode

    private var sortedEntries: [DrinkEntry] {
        store.entries.sorted(by: { $0.timestamp > $1.timestamp })
    }

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    var body: some View {
        AppScreenScaffold {
            ScreenIntroCard(
                title: "Session Timeline",
                subtitle: "Track each log and clean up anything accidental."
            )

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
        .navigationTitle("History")
        .toolbar {
            EditButton()
                .tint(NightTheme.accent)
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

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Text(DisplayFormatter.standardDrinks(entry.standardDrinks))
                    .font(NightTheme.bodyFont.weight(.semibold))
                    .foregroundStyle(NightTheme.accentSoft)

                if isEditing {
                    Button(role: .destructive) {
                        store.deleteEntries(ids: Set([entry.id]))
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(NightTheme.captionFont.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(NightTheme.warning)
                }
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
