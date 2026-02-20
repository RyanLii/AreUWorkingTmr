import Foundation

enum BuzzMoodLevel: Int, CaseIterable {
    case nightJustBegan
    case goodVibes
    case buzzin
    case wavy
    case onFire
    case tooLit
    case takeItEasyZone
}

struct BuzzStatusDescriptor: Equatable {
    let level: BuzzMoodLevel
    let title: String
    let description: String

    static func from(snapshot: SessionSnapshot) -> BuzzStatusDescriptor {
        let effective = max(snapshot.effectiveStandardDrinks, 0)

        if effective < 0.3 {
            return BuzzStatusDescriptor(
                level: .nightJustBegan,
                title: "Night just began",
                description: "Fresh start. Keep it smooth."
            )
        }

        if effective < 0.8 {
            return BuzzStatusDescriptor(
                level: .goodVibes,
                title: "Good vibes",
                description: "Light buzz, easy flow."
            )
        }

        if effective < 1.6 {
            return BuzzStatusDescriptor(
                level: .buzzin,
                title: "Buzzin'",
                description: "You're feeling it."
            )
        }

        if effective < 2.6 {
            return BuzzStatusDescriptor(
                level: .wavy,
                title: "Wavy",
                description: "Mood is up. Slow the pace a touch."
            )
        }

        if effective < 3.8 {
            return BuzzStatusDescriptor(
                level: .onFire,
                title: "On fire",
                description: "Big energy. Water break now."
            )
        }

        if effective < 5.0 {
            return BuzzStatusDescriptor(
                level: .tooLit,
                title: "Too lit",
                description: "You're peaking hard. Pause and hydrate."
            )
        }

        return BuzzStatusDescriptor(
            level: .takeItEasyZone,
            title: "Take-it-easy zone",
            description: "Heavy zone. Chill, water, no hero mode."
        )
    }
}
