import XCTest

#if canImport(SaferNightCore)
@testable import SaferNightCore
#endif

final class DrinkParserTests: XCTestCase {
    func testParseBeerSentence() {
        let parsed = DrinkParser.parse("2 beers 500ml 5%")
        XCTAssertEqual(parsed?.category, .beer)
        XCTAssertEqual(parsed?.quantity, 2)
        XCTAssertEqual(parsed?.volumeMl ?? 0, 500, accuracy: 0.1)
        XCTAssertEqual(parsed?.abvPercent ?? 0, 5, accuracy: 0.1)
    }

    func testParseImperialVolume() {
        let parsed = DrinkParser.parse("1 cocktail 6oz 18%")
        XCTAssertEqual(parsed?.category, .cocktail)
        XCTAssertEqual(parsed?.quantity, 1)
        XCTAssertEqual(parsed?.volumeMl ?? 0, 177.4, accuracy: 1)
        XCTAssertEqual(parsed?.abvPercent ?? 0, 18, accuracy: 0.1)
    }

    func testParseFailsForUnrecognizedText() {
        XCTAssertNil(DrinkParser.parse("hello world"))
    }
}
