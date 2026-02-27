import Foundation

struct ServingOption: Identifiable, Hashable {
    let id: String
    let name: String
    let volumeMl: Double

    var subtitle: String {
        "\(Int(volumeMl))ml"
    }
}

struct DrinkDetailTemplate {
    let title: String
    let servings: [ServingOption]
    let abvOptions: [Double]
}

enum ServingConfig {
    static func detailTemplate(for category: DrinkCategory, region: RegionStandard) -> DrinkDetailTemplate {
        switch category {
        case .beer:
            return DrinkDetailTemplate(
                title: "Beer",
                servings: [
                    ServingOption(id: "beer_schooner", name: "Schooner", volumeMl: 425),
                    ServingOption(id: "beer_pint", name: "Pint", volumeMl: 568),
                    ServingOption(id: "beer_bottle", name: "Bottle", volumeMl: 330),
                    ServingOption(id: "beer_can", name: "Can", volumeMl: 375)
                ],
                abvOptions: [3.5, 4.2, 5.0, 6.0, 7.5, 9.0]
            )

        case .wine:
            let servings: [ServingOption]
            switch region {
            case .au10g:
                servings = [
                    ServingOption(id: "wine_small_au", name: "Small", volumeMl: 100),
                    ServingOption(id: "wine_std_au", name: "Standard", volumeMl: 150),
                    ServingOption(id: "wine_large_au", name: "Large", volumeMl: 200),
                    ServingOption(id: "wine_bottle_au", name: "Bottle", volumeMl: 750)
                ]
            case .uk8g:
                servings = [
                    ServingOption(id: "wine_125", name: "125ml", volumeMl: 125),
                    ServingOption(id: "wine_175", name: "175ml", volumeMl: 175),
                    ServingOption(id: "wine_250", name: "250ml", volumeMl: 250),
                    ServingOption(id: "wine_bottle_uk", name: "Bottle", volumeMl: 750)
                ]
            case .us14g:
                servings = [
                    ServingOption(id: "wine_5oz", name: "5oz Pour", volumeMl: 148),
                    ServingOption(id: "wine_6oz", name: "6oz Pour", volumeMl: 177),
                    ServingOption(id: "wine_9oz", name: "9oz Large", volumeMl: 266),
                    ServingOption(id: "wine_bottle_us", name: "Bottle", volumeMl: 750)
                ]
            }
            return DrinkDetailTemplate(
                title: "Wine",
                servings: servings,
                abvOptions: [9.0, 11.0, 12.0, 13.5, 15.0]
            )

        case .shot:
            let servings: [ServingOption]
            switch region {
            case .au10g:
                servings = [
                    ServingOption(id: "shot_single_au", name: "Single", volumeMl: 30),
                    ServingOption(id: "shot_classic_au", name: "Classic", volumeMl: 45),
                    ServingOption(id: "shot_double_au", name: "Double", volumeMl: 60)
                ]
            case .uk8g:
                servings = [
                    ServingOption(id: "shot_uk_single", name: "Single", volumeMl: 25),
                    ServingOption(id: "shot_uk_large", name: "Large", volumeMl: 35),
                    ServingOption(id: "shot_uk_double", name: "Double", volumeMl: 50)
                ]
            case .us14g:
                servings = [
                    ServingOption(id: "shot_1oz", name: "1oz", volumeMl: 30),
                    ServingOption(id: "shot_1_5oz", name: "1.5oz", volumeMl: 44),
                    ServingOption(id: "shot_double_us", name: "Double", volumeMl: 60)
                ]
            }
            return DrinkDetailTemplate(
                title: "Shot",
                servings: servings,
                abvOptions: [30.0, 35.0, 40.0, 45.0, 50.0]
            )

        case .cocktail:
            return DrinkDetailTemplate(
                title: "Cocktail",
                servings: [
                    ServingOption(id: "cocktail_small", name: "Small", volumeMl: 120),
                    ServingOption(id: "cocktail_standard", name: "Standard", volumeMl: 180),
                    ServingOption(id: "cocktail_tall", name: "Tall", volumeMl: 250),
                    ServingOption(id: "cocktail_jumbo", name: "Jumbo", volumeMl: 330)
                ],
                abvOptions: [8.0, 12.0, 16.0, 20.0, 24.0]
            )

        case .spirits:
            return DrinkDetailTemplate(
                title: "Spirits",
                servings: [
                    ServingOption(id: "spirits_nip", name: "Nip", volumeMl: 30),
                    ServingOption(id: "spirits_single", name: "Single", volumeMl: 45),
                    ServingOption(id: "spirits_double", name: "Double", volumeMl: 60),
                    ServingOption(id: "spirits_large", name: "Large", volumeMl: 90)
                ],
                abvOptions: [35.0, 40.0, 45.0, 50.0, 55.0]
            )

        case .custom:
            return DrinkDetailTemplate(
                title: "Custom",
                servings: [],
                abvOptions: [5.0, 8.0, 12.0, 18.0, 30.0, 40.0]
            )
        }
    }
}
