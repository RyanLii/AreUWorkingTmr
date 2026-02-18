import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore

    @State private var weightText = ""
    @State private var heightText = ""
    @State private var sex: BiologicalSex = .other
    @State private var unit: UnitPreference = .metric
    @State private var region: RegionStandard = .defaultForCurrentLocale()
    @State private var homeLatText = ""
    @State private var homeLonText = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                NightBackdrop()

                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Profile Tuning")
                                .font(NightTheme.sectionFont)
                                .foregroundStyle(.white)

                            Text("These inputs only improve estimate accuracy and quick-add defaults.")
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

                    Section {
                        TextField(weightFieldTitle, text: $weightText)
                            .keyboardType(.decimalPad)

                        TextField(heightFieldTitle, text: $heightText)
                            .keyboardType(.decimalPad)

                        Picker("Biological sex", selection: $sex) {
                            ForEach(BiologicalSex.allCases, id: \.rawValue) { option in
                                Text(option.rawValue.capitalized).tag(option)
                            }
                        }

                        Picker("Units", selection: $unit) {
                            ForEach(UnitPreference.allCases, id: \.rawValue) { option in
                                Text(option.rawValue.capitalized).tag(option)
                            }
                        }

                        Picker("Standard drink", selection: $region) {
                            ForEach(RegionStandard.allCases, id: \.rawValue) { option in
                                Text(option.label).tag(option)
                            }
                        }

                        Text("Region controls serving standards (for example AU schooner vs US tallboy/can).")
                            .font(.footnote)
                            .foregroundStyle(NightTheme.labelSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        sectionHeader("Personalized Estimate")
                    }
                    .listRowBackground(Color.black.opacity(0.26))

                    Section {
                        ForEach(DrinkCategory.allCases, id: \.rawValue) { category in
                            defaultRow(for: category)
                        }

                        Text("Change defaults on Watch detail screens using 'Set As Default'.")
                            .font(.footnote)
                            .foregroundStyle(NightTheme.labelSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        sectionHeader("Quick Add Defaults")
                    }
                    .listRowBackground(Color.black.opacity(0.26))

                    Section {
                        TextField("Latitude", text: $homeLatText)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("Longitude", text: $homeLonText)
                            .keyboardType(.numbersAndPunctuation)
                    } header: {
                        sectionHeader("Home Location (optional)")
                    }
                    .listRowBackground(Color.black.opacity(0.26))

                    Section {
                        Button("Save profile") {
                            saveProfile()
                        }
                        .foregroundStyle(NightTheme.accent)
                    }
                    .listRowBackground(Color.black.opacity(0.26))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .tint(NightTheme.accent)
                .environment(\.colorScheme, .dark)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Profile")
            .onAppear {
                loadFromStore()
            }
            .onChange(of: unit) { _, _ in
                // Re-render numbers in the selected unit so inputs stay intuitive.
                weightText = formattedWeightForInput(store.profile.weightKg)
                heightText = formattedHeightForInput(store.profile.heightCm)
            }
        }
    }

    private var weightFieldTitle: String {
        unit == .metric ? "Weight (kg)" : "Weight (lb)"
    }

    private var heightFieldTitle: String {
        unit == .metric ? "Height (cm)" : "Height (in)"
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

            Spacer()

            Button("Reset") {
                store.resetPreferredPreset(category: category)
            }
            .buttonStyle(.bordered)
            .font(.footnote)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(NightTheme.captionFont)
            .foregroundStyle(NightTheme.labelSoft)
            .textCase(.uppercase)
    }

    private func loadFromStore() {
        sex = store.profile.biologicalSex
        unit = store.profile.unitPreference
        region = store.profile.regionStandard

        weightText = formattedWeightForInput(store.profile.weightKg)
        heightText = formattedHeightForInput(store.profile.heightCm)

        if let home = store.profile.homeLocation {
            homeLatText = String(home.latitude)
            homeLonText = String(home.longitude)
        } else {
            homeLatText = ""
            homeLonText = ""
        }
    }

    private func saveProfile() {
        let weightInput = Double(weightText)
        let heightInput = Double(heightText)

        let weightKg = normalizedWeightKg(from: weightInput) ?? store.profile.weightKg
        let heightCm = normalizedHeightCm(from: heightInput) ?? store.profile.heightCm

        let lat = Double(homeLatText)
        let lon = Double(homeLonText)

        let location: LocationSnapshot?
        if let lat, let lon {
            location = LocationSnapshot(latitude: lat, longitude: lon)
        } else {
            location = nil
        }

        let profile = UserProfile(
            weightKg: min(max(weightKg, 35), 220),
            heightCm: min(max(heightCm, 130), 220),
            biologicalSex: sex,
            unitPreference: unit,
            regionStandard: region,
            workingTomorrow: store.profile.workingTomorrow,
            homeLocation: location,
            drinkPreferences: store.profile.drinkPreferences
        )

        store.updateProfile(profile)
    }

    private func formattedWeightForInput(_ weightKg: Double) -> String {
        switch unit {
        case .metric:
            return String(format: "%.1f", weightKg)
        case .imperial:
            return String(format: "%.0f", weightKg / 0.45359237)
        }
    }

    private func formattedHeightForInput(_ heightCm: Double) -> String {
        switch unit {
        case .metric:
            return String(format: "%.0f", heightCm)
        case .imperial:
            return String(format: "%.0f", heightCm / 2.54)
        }
    }

    private func normalizedWeightKg(from input: Double?) -> Double? {
        guard let input else { return nil }
        switch unit {
        case .metric:
            return input
        case .imperial:
            return input * 0.45359237
        }
    }

    private func normalizedHeightCm(from input: Double?) -> Double? {
        guard let input else { return nil }
        switch unit {
        case .metric:
            return input
        case .imperial:
            return input * 2.54
        }
    }
}
