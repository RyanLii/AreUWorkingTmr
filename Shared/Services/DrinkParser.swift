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
        let volumeMl = parseVolumeMl(from: normalized) ?? defaultVolume(for: category)
        let abv = parseABV(from: normalized) ?? defaultABV(for: category)

        return ParsedDrinkIntent(
            category: category,
            quantity: quantity,
            volumeMl: volumeMl,
            abvPercent: abv
        )
    }

    private static func parseCategory(from text: String) -> DrinkCategory? {
        let keywordMap: [(DrinkCategory, [String])] = [
            (.beer, ["beer", "beers", "lager", "ipa", "ale", "pint", "schooner", "middy", "pot", "stubby"]),
            (.wine, ["wine", "red", "white", "rose", "rosé", "prosecco", "champagne", "sparkling"]),
            (.shot, ["shot", "shots"]),
            (.cocktail, ["cocktail", "margarita", "martini", "mojito", "spritz", "daiquiri"]),
            (.spirits, ["whisky", "whiskey", "vodka", "rum", "tequila", "gin", "spirit", "bourbon", "brandy"]),
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
        let wordNumbers: [String: Int] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10
        ]

        for (word, value) in wordNumbers {
            if text.contains(word) { return value }
        }

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
        // Numeric ml / oz
        if let value = firstMatch(pattern: #"(\d+(?:\.\d+)?)\s*ml"#, in: text), let ml = Double(value) {
            return ml
        }
        if let value = firstMatch(pattern: #"(\d+(?:\.\d+)?)\s*oz"#, in: text), let oz = Double(value) {
            return oz * 29.5735
        }

        // Named serving sizes
        let servingMap: [(String, Double)] = [
            ("schooner", 425),
            ("pint", 568),
            ("middy", 285),
            ("pot", 285),
            ("stubby", 375),
            ("half pint", 284),
            ("nip", 30)
        ]
        for (name, ml) in servingMap {
            if text.contains(name) { return ml }
        }

        return nil
    }

    private static func parseABV(from text: String) -> Double? {
        if let value = firstMatch(pattern: #"(\d+(?:\.\d+)?)\s*%"#, in: text), let abv = Double(value) {
            return abv
        }
        return nil
    }

    private static func defaultVolume(for category: DrinkCategory) -> Double {
        switch category {
        case .beer:     return 355
        case .wine:     return 150
        case .shot:     return 44
        case .cocktail: return 180
        case .spirits:  return 60
        case .custom:   return 355
        }
    }

    private static func defaultABV(for category: DrinkCategory) -> Double {
        switch category {
        case .beer:     return 5
        case .wine:     return 12
        case .shot:     return 40
        case .cocktail: return 18
        case .spirits:  return 40
        case .custom:   return 5
        }
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
