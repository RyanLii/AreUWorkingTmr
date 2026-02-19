import SwiftUI

struct VoiceLogView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var locationMonitor: WatchLocationMonitor

    @State private var input = ""
    @State private var parseError: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Text Mate")
                    .font(WatchNightTheme.titleFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text("Type naturally. We parse and log.")
                    .font(WatchNightTheme.captionFont)
                    .foregroundStyle(WatchNightTheme.accentSoft)

                TextField("2 beers 500ml 5%", text: $input)
                    .font(WatchNightTheme.bodyFont)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )
                    )

                Button {
                    guard let parsed = DrinkParser.parse(input) else {
                        parseError = "Couldn't parse. Try drink + amount."
                        return
                    }
                    store.addVoiceDrink(
                        parsed: parsed,
                        location: locationMonitor.currentLocation?.coordinate
                    )
                    parseError = nil
                    input = ""
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Text Mate Log")
                    }
                    .font(WatchNightTheme.bodyFont)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(WatchNightTheme.accent)
                    )
                }
                .buttonStyle(.plain)

                if let parsed = DrinkParser.parse(input), !input.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Preview")
                            .font(WatchNightTheme.captionFont)
                            .foregroundStyle(WatchNightTheme.labelSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text("\(parsed.quantity)x \(parsed.category.title)")
                            .font(WatchNightTheme.bodyFont)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        if let volume = parsed.volumeMl {
                            Text("Volume \(Int(volume))ml")
                                .font(WatchNightTheme.captionFont)
                                .foregroundStyle(WatchNightTheme.label)
                        }

                        if let abv = parsed.abvPercent {
                            Text("ABV \(abv, specifier: "%.1f")%")
                                .font(WatchNightTheme.captionFont)
                                .foregroundStyle(WatchNightTheme.label)
                        }
                    }
                    .watchCard()
                }

                if let parseError {
                    Label(parseError, systemImage: "exclamationmark.triangle.fill")
                        .font(WatchNightTheme.captionFont)
                        .foregroundStyle(WatchNightTheme.warning)
                        .watchCard(highlighted: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
    }
}
