import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore

    private var profile: UserProfile { store.profile }

    @State private var weightInput: String = ""
    @FocusState private var weightFocused: Bool

    private func estimatedRateText(for weightKg: Double) -> String {
        let rate = min(max(weightKg * 0.114 / profile.regionStandard.gramsPerStandardDrink, 0.5), 1.2)
        return String(format: "Trend pace setting: %.2f std/hr", rate)
    }

    var body: some View {
        AppScreenScaffold {
            SectionCard("Body Metrics") {
                bodyText("Add your weight to personalize trend pacing. Leave it empty to use the default pace for your region.")

                Divider().overlay(Color.white.opacity(0.12))

                HStack {
                    Text("Weight")
                        .font(NightTheme.bodyFont)
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 6) {
                        TextField("—", text: $weightInput)
                            .font(NightTheme.bodyFont.weight(.medium))
                            .foregroundStyle(NightTheme.accentSoft)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($weightFocused)
                            .frame(width: 64)
                            .onChange(of: weightFocused) { _, focused in
                                if !focused { commitWeight() }
                            }
                        Text("kg")
                            .font(NightTheme.bodyFont)
                            .foregroundStyle(NightTheme.label)
                        if !weightInput.isEmpty {
                            Button {
                                weightInput = ""
                                var p = profile
                                p.weightKg = nil
                                store.updateProfile(p)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(NightTheme.labelSoft)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let kg = profile.weightKg {
                    Text(estimatedRateText(for: kg))
                        .font(NightTheme.captionFont)
                        .foregroundStyle(NightTheme.accentSoft)
                }
            }

            SectionCard("Standard Drinks") {
                bodyText("\"Standard drink\" is a unit of pure alcohol. Different countries define it differently — this setting keeps your logging consistent for your region.")

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

        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profile")
                    .font(NightTheme.sectionFont.weight(.bold))
                    .foregroundStyle(.white)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { weightFocused = false }
                    .foregroundStyle(NightTheme.accent)
            }
        }
        .onAppear {
            weightInput = profile.weightKg.map { "\(Int($0))" } ?? ""
        }
    }

    private func commitWeight() {
        let trimmed = weightInput.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            var p = profile
            p.weightKg = nil
            store.updateProfile(p)
            return
        }
        guard let value = Double(trimmed), value >= 20, value <= 300 else {
            weightInput = profile.weightKg.map { "\(Int($0))" } ?? ""
            return
        }
        var p = profile
        p.weightKg = (value * 10).rounded() / 10
        store.updateProfile(p)
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
            return "Australian standard: 1 std drink = 10g alcohol. A 375ml mid-strength beer (3.5%) is about 1.0 std."
        case .uk8g:
            return "UK unit: 1 unit = 8g alcohol. A 568ml pint at 4% is about 2.3 units."
        case .us14g:
            return "US standard: 1 drink = 14g alcohol. A 355ml beer at 5% is about 1.0 std."
        }
    }
}
