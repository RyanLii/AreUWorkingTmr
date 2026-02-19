import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore

    @State private var weightText = ""
    @State private var heightText = ""
    @State private var unit: UnitPreference = .metric
    @State private var region: RegionStandard = .defaultForCurrentLocale()

    var body: some View {
        AppScreenScaffold {
            ScreenIntroCard(
                title: "Profile Tuning",
                subtitle: "These inputs only improve estimate accuracy and quick-add defaults."
            )

            SectionCard("Personalized Estimate") {
                inputField(weightFieldTitle, text: $weightText, keyboard: .decimalPad)
                inputField(heightFieldTitle, text: $heightText, keyboard: .decimalPad)

                Picker("Units", selection: $unit) {
                    ForEach(UnitPreference.allCases, id: \.rawValue) { option in
                        Text(option.rawValue.capitalized).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(NightTheme.accent)

                Picker("Standard drink", selection: $region) {
                    ForEach(RegionStandard.allCases, id: \.rawValue) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(NightTheme.accent)

                Text("Region controls serving standards (for example AU schooner vs US tallboy/can).")
                    .font(.footnote)
                    .foregroundStyle(NightTheme.labelSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Changes auto-save when you leave this screen.")
                    .font(.footnote)
                    .foregroundStyle(NightTheme.labelSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SectionCard("Quick Add Defaults") {
                VStack(spacing: 10) {
                    ForEach(DrinkCategory.allCases, id: \.rawValue) { category in
                        defaultRow(for: category)
                    }
                }

                Text("Change defaults on Watch detail screens using 'Set As Default'.")
                    .font(.footnote)
                    .foregroundStyle(NightTheme.labelSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("Profile")
        .onAppear {
            loadFromStore()
        }
        .onChange(of: unit) { oldUnit, _ in
            saveProfile(usingInputUnit: oldUnit)
            weightText = formattedWeightForInput(store.profile.weightKg)
            heightText = formattedHeightForInput(store.profile.heightCm)
        }
        .onChange(of: region) { _, _ in
            saveProfile()
        }
        .onDisappear {
            saveProfile()
        }
    }

    private var weightFieldTitle: String { unit == .metric ? "Weight (kg)" : "Weight (lb)" }
    private var heightFieldTitle: String { unit == .metric ? "Height (cm)" : "Height (in)" }

    private func inputField(_ title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboard)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .foregroundStyle(.white)
    }

    private func defaultRow(for category: DrinkCategory) -> some View {
        let preset = store.preset(for: category)

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .foregroundStyle(.white)
                Text("\(preset.name) · \(Int(preset.defaultVolumeMl))ml · \(preset.defaultABV, specifier: "%.1f")%")
                    .font(.footnote)
                    .foregroundStyle(NightTheme.label)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Reset") {
                store.resetPreferredPreset(category: category)
            }
            .buttonStyle(.bordered)
            .font(.footnote)
            .tint(NightTheme.accent)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func loadFromStore() {
        unit = store.profile.unitPreference
        region = store.profile.regionStandard

        weightText = formattedWeightForInput(store.profile.weightKg)
        heightText = formattedHeightForInput(store.profile.heightCm)
    }

    private func saveProfile(usingInputUnit inputUnit: UnitPreference? = nil) {
        let weightInput = Double(weightText)
        let heightInput = Double(heightText)
        let unitForInput = inputUnit ?? unit

        let weightKg = normalizedWeightKg(from: weightInput, using: unitForInput) ?? store.profile.weightKg
        let heightCm = normalizedHeightCm(from: heightInput, using: unitForInput) ?? store.profile.heightCm

        let profile = UserProfile(
            weightKg: min(max(weightKg, 35), 220),
            heightCm: min(max(heightCm, 130), 220),
            biologicalSex: store.profile.biologicalSex,
            unitPreference: unit,
            regionStandard: region,
            workingTomorrow: store.profile.workingTomorrow,
            homeLocation: store.profile.homeLocation,
            drinkPreferences: store.profile.drinkPreferences
        )

        store.updateProfile(profile)
    }

    private func formattedWeightForInput(_ weightKg: Double) -> String {
        switch unit {
        case .metric: return String(format: "%.1f", weightKg)
        case .imperial: return String(format: "%.0f", weightKg / 0.45359237)
        }
    }

    private func formattedHeightForInput(_ heightCm: Double) -> String {
        switch unit {
        case .metric: return String(format: "%.0f", heightCm)
        case .imperial: return String(format: "%.0f", heightCm / 2.54)
        }
    }

    private func normalizedWeightKg(from input: Double?, using unitPreference: UnitPreference) -> Double? {
        guard let input else { return nil }
        switch unitPreference {
        case .metric: return input
        case .imperial: return input * 0.45359237
        }
    }

    private func normalizedHeightCm(from input: Double?, using unitPreference: UnitPreference) -> Double? {
        guard let input else { return nil }
        switch unitPreference {
        case .metric: return input
        case .imperial: return input * 2.54
        }
    }
}
