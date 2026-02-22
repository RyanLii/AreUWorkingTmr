import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore

    private var profile: UserProfile { store.profile }

    var body: some View {
        AppScreenScaffold {
            SectionCard("Standard Drinks") {
                bodyText("\"Standard drink\" is a unit of pure alcohol. Different countries define it differently — this setting ensures the model counts correctly for your region.")

                Divider().overlay(Color.white.opacity(0.12))

                pickerRow(
                    label: "Region",
                    value: regionLabel(profile.regionStandard)
                ) {
                    ForEach(RegionStandard.allCases, id: \.self) { region in
                        Button(regionLabel(region)) {
                            var p = profile
                            p.regionStandard = region
                            store.updateProfile(p)
                        }
                    }
                }

                Divider().overlay(Color.white.opacity(0.08))

                bodyText(regionExplanation(profile.regionStandard))
            }

            SectionCard("Display") {
                bodyText("Controls how volumes are shown across the app.")

                Divider().overlay(Color.white.opacity(0.12))

                pickerRow(
                    label: "Units",
                    value: profile.unitPreference == .metric ? "Metric (ml)" : "Imperial (fl oz)"
                ) {
                    Button("Metric (ml)") {
                        var p = profile
                        p.unitPreference = .metric
                        store.updateProfile(p)
                    }
                    Button("Imperial (fl oz)") {
                        var p = profile
                        p.unitPreference = .imperial
                        store.updateProfile(p)
                    }
                }
            }

            SectionCard("Body Metrics") {
                HStack(spacing: 10) {
                    Image(systemName: "clock.badge.questionmark")
                        .foregroundStyle(NightTheme.labelSoft)
                        .frame(width: 20)
                    bodyText("Height and weight coming in a future update. These will let the model give more personalised estimates.")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profile")
                    .font(NightTheme.sectionFont.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func pickerRow<MenuContent: View>(
        label: String,
        value: String,
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        HStack {
            Text(label)
                .font(NightTheme.bodyFont)
                .foregroundStyle(.white)
            Spacer()
            Menu {
                menuContent()
            } label: {
                HStack(spacing: 4) {
                    Text(value)
                        .font(NightTheme.bodyFont)
                        .foregroundStyle(NightTheme.accentSoft)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NightTheme.accentSoft)
                }
            }
        }
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(NightTheme.bodyFont)
            .foregroundStyle(NightTheme.label)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func regionLabel(_ region: RegionStandard) -> String {
        switch region {
        case .au10g: return "Australia / NZ (10g)"
        case .uk8g:  return "UK / Europe (8g)"
        case .us14g: return "USA (14g)"
        }
    }

    private func regionExplanation(_ region: RegionStandard) -> String {
        switch region {
        case .au10g:
            return "Australian standard: 1 std drink = 10g alcohol. A 375ml mid-strength beer (3.5%) ≈ 1.0 std."
        case .uk8g:
            return "UK unit: 1 unit = 8g alcohol. A 568ml pint at 4% ≈ 2.3 units. Tighter threshold than AU/US."
        case .us14g:
            return "US standard: 1 drink = 14g alcohol. A 355ml beer at 5% ≈ 1.0 std. Higher threshold than AU/UK."
        }
    }
}
