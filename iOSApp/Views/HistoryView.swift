import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.editMode) private var editMode

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    // Group all entries into sessions, newest session first
    private var sessions: [(key: String, date: Date, entries: [DrinkEntry])] {
        let grouped = Dictionary(grouping: store.entries) { entry in
            SessionClock.key(for: entry.timestamp)
        }
        return grouped
            .map { key, entries in
                let sessionStart = SessionClock.interval(containing: entries[0].timestamp).start
                let sorted = entries.sorted { $0.timestamp > $1.timestamp }
                return (key: key, date: sessionStart, entries: sorted)
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        AppScreenScaffold {
            if sessions.isEmpty {
                SectionCard("Timeline") {
                    Text("No drinks logged yet")
                        .font(NightTheme.sectionFont)
                        .foregroundStyle(.white)
                    Text("Your history appears here after your first log.")
                        .font(NightTheme.bodyFont)
                        .foregroundStyle(NightTheme.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(sessions, id: \.key) { session in
                    sessionCard(session)
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

    private func sessionCard(_ session: (key: String, date: Date, entries: [DrinkEntry])) -> some View {
        let total = session.entries.reduce(0) { $0 + $1.standardDrinks }
        let isToday = SessionClock.key(for: .now) == session.key

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isToday ? "Tonight" : sessionDateLabel(session.date))
                        .font(NightTheme.sectionFont.weight(.bold))
                        .foregroundStyle(.white)
                    Text(weekdayLabel(session.date))
                        .font(NightTheme.captionFont)
                        .foregroundStyle(NightTheme.labelSoft)
                }
                Spacer()
                Text(DisplayFormatter.standardDrinks(total))
                    .font(NightTheme.bodyFont.weight(.semibold))
                    .foregroundStyle(NightTheme.accentSoft)
            }

            Divider().overlay(Color.white.opacity(0.10))

            VStack(spacing: 8) {
                ForEach(session.entries) { entry in
                    entryRow(entry)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func entryRow(_ entry: DrinkEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.servingName ?? entry.category.title)
                        .font(NightTheme.bodyFont.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("\(entry.category.title) · \(Int(entry.volumeMl))ml · \(entry.abvPercent, specifier: "%.1f")%")
                        .font(NightTheme.captionFont)
                        .foregroundStyle(NightTheme.label)

                    Text(entry.timestamp, style: .time)
                        .font(NightTheme.captionFont)
                        .foregroundStyle(NightTheme.labelSoft)
                }

                Spacer(minLength: 8)

                Text(DisplayFormatter.standardDrinks(entry.standardDrinks))
                    .font(NightTheme.captionFont.weight(.semibold))
                    .foregroundStyle(NightTheme.accentSoft)
            }

            if isEditing {
                Button(role: .destructive) {
                    store.deleteEntries(ids: Set([entry.id]))
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(NightTheme.captionFont.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(NightTheme.warning)
            }
        }
    }

    private func sessionDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func weekdayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date) + " night"
    }
}
