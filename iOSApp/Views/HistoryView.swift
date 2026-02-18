import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                NightBackdrop()

                List {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Session Timeline")
                                .font(NightTheme.sectionFont)
                                .foregroundStyle(.white)

                            Text("Track each log and clean up anything accidental.")
                                .font(NightTheme.bodyFont)
                                .foregroundStyle(NightTheme.label)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                        .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 6, trailing: 24))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    if store.entries.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No drinks logged yet")
                                .font(NightTheme.sectionFont)
                                .foregroundStyle(.white)
                            Text("Your timeline appears here after your first quick add or voice log.")
                                .font(NightTheme.bodyFont)
                                .foregroundStyle(NightTheme.label)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(store.entries.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.servingName ?? entry.category.title)
                                        .font(NightTheme.sectionFont)
                                        .foregroundStyle(.white)

                                    Text("\(entry.category.title) · \(Int(entry.volumeMl))ml · \(entry.abvPercent, specifier: "%.1f")%")
                                        .font(NightTheme.bodyFont)
                                        .foregroundStyle(NightTheme.label)
                                        .lineLimit(2)
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .listRowInsets(EdgeInsets(top: 6, leading: 24, bottom: 6, trailing: 24))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: store.deleteEntries)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("History")
            .toolbar {
                EditButton()
                    .tint(NightTheme.accent)
            }
        }
    }
}
