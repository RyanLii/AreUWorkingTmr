import Foundation
import Testing
@testable import SaferNightCore

@Suite("ServingConfig")
struct ServingConfigTests {

    @Test func allCategoriesReturnNonEmptyTitleAndABV() {
        for category in DrinkCategory.allCases {
            for region in RegionStandard.allCases {
                let template = ServingConfig.detailTemplate(for: category, region: region)
                #expect(!template.title.isEmpty)
                #expect(!template.abvOptions.isEmpty)
            }
        }
    }

    @Test func customCategoryHasNoServings() {
        let template = ServingConfig.detailTemplate(for: .custom, region: .au10g)
        #expect(template.servings.isEmpty)
    }

    @Test func beerServingsAreSameAcrossRegions() {
        let au = ServingConfig.detailTemplate(for: .beer, region: .au10g)
        let uk = ServingConfig.detailTemplate(for: .beer, region: .uk8g)
        let us = ServingConfig.detailTemplate(for: .beer, region: .us14g)
        #expect(au.servings == uk.servings)
        #expect(uk.servings == us.servings)
    }

    @Test func wineServingsVaryByRegion() {
        let au = ServingConfig.detailTemplate(for: .wine, region: .au10g)
        let uk = ServingConfig.detailTemplate(for: .wine, region: .uk8g)
        let us = ServingConfig.detailTemplate(for: .wine, region: .us14g)
        #expect(au.servings != uk.servings)
        #expect(uk.servings != us.servings)
    }

    @Test func shotServingsVaryByRegion() {
        let au = ServingConfig.detailTemplate(for: .shot, region: .au10g)
        let uk = ServingConfig.detailTemplate(for: .shot, region: .uk8g)
        let us = ServingConfig.detailTemplate(for: .shot, region: .us14g)
        #expect(au.servings != uk.servings)
        #expect(uk.servings != us.servings)
    }

    @Test func servingIdsAreUniquePerTemplate() {
        for category in DrinkCategory.allCases {
            for region in RegionStandard.allCases {
                let template = ServingConfig.detailTemplate(for: category, region: region)
                let ids = template.servings.map(\.id)
                #expect(Set(ids).count == ids.count, "Duplicate serving ID in \(category) / \(region)")
            }
        }
    }

    @Test func servingSubtitleFormatsCorrectly() {
        let option = ServingOption(id: "test", name: "Test", volumeMl: 425)
        #expect(option.subtitle == "425ml")
    }
}
