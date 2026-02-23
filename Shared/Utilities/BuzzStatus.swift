import Foundation

enum BuzzMoodLevel: Int, CaseIterable {
    case underTheRadar
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
                level: .underTheRadar,
                title: "Under the radar",
                description: "Trace load. No measurable impact estimated."
            )
        }

        if effective < 0.8 {
            return BuzzStatusDescriptor(
                level: .goodVibes,
                title: "Good vibes",
                description: "Light load. Within single-drink range."
            )
        }

        if effective < 1.6 {
            return BuzzStatusDescriptor(
                level: .buzzin,
                title: "Buzzin'",
                description: "Moderate load. Absorption window active."
            )
        }

        if effective < 2.6 {
            return BuzzStatusDescriptor(
                level: .wavy,
                title: "Wavy",
                description: "Above common two-drink range."
            )
        }

        if effective < 3.8 {
            return BuzzStatusDescriptor(
                level: .onFire,
                title: "On fire",
                description: "Approaching projected peak."
            )
        }

        if effective < 5.0 {
            return BuzzStatusDescriptor(
                level: .tooLit,
                title: "Heavy load",
                description: "Heavy load. Extended recovery window ahead."
            )
        }

        return BuzzStatusDescriptor(
            level: .takeItEasyZone,
            title: "High load zone",
            description: "Very high load. Long clear window projected."
        )
    }
}
