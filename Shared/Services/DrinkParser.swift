import Foundation

struct ParsedDrinkIntent: Equatable {
    var category: DrinkCategory
    var quantity: Int
    var volumeMl: Double?
    var abvPercent: Double?
}

enum DrinkParser {
    static func parse(_ input: String) -> ParsedDrinkIntent? {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        guard let category = parseCategory(from: normalized) else { return nil }

        let quantity = parseQuantity(from: normalized)
        let volumeMl = parseVolumeMl(from: normalized)
        let abv = parseABV(from: normalized)

        return ParsedDrinkIntent(
            category: category,
            quantity: quantity,
            volumeMl: volumeMl,
            abvPercent: abv
        )
    }

    private static func parseCategory(from text: String) -> DrinkCategory? {
        let keywordMap: [(DrinkCategory, [String])] = [
            (.beer, ["beer", "beers", "lager", "ipa"]),
            (.wine, ["wine", "red", "white", "rose"]),
            (.shot, ["shot", "shots"]),
            (.cocktail, ["cocktail", "margarita", "martini", "mojito"]),
            (.spirits, ["whisky", "whiskey", "vodka", "rum", "tequila", "gin", "spirit"]),
            (.custom, ["custom", "drink", "glass"])
        ]

        for (category, keywords) in keywordMap {
            if keywords.contains(where: { text.contains($0) }) {
                return category
            }
        }
        return nil
    }

    private static func parseQuantity(from text: String) -> Int {
        let patterns = [
            #"(\d+)\s*(x|times|beers|beer|shots|shot|glasses|drinks)"#,
            #"^\s*(\d+)\s+"#
        ]

        for pattern in patterns {
            if let value = firstMatch(pattern: pattern, in: text), let number = Int(value) {
                return max(1, number)
            }
        }

        return 1
    }

    private static func parseVolumeMl(from text: String) -> Double? {
        if let value = firstMatch(pattern: #"(\d+(?:\.\d+)?)\s*ml"#, in: text), let ml = Double(value) {
            return ml
        }
        if let value = firstMatch(pattern: #"(\d+(?:\.\d+)?)\s*oz"#, in: text), let oz = Double(value) {
            return oz * 29.5735
        }
        return nil
    }

    private static func parseABV(from text: String) -> Double? {
        if let value = firstMatch(pattern: #"(\d+(?:\.\d+)?)\s*%"#, in: text), let abv = Double(value) {
            return abv
        }
        return nil
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[valueRange])
    }
}
