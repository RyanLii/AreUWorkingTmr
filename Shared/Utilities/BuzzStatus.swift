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
                description: "Still sober enough to regret nothing. Yet."
            )
        }

        if effective < 0.8 {
            return BuzzStatusDescriptor(
                level: .goodVibes,
                title: "Good vibes",
                description: "One in. Charming and probably right."
            )
        }

        if effective < 1.6 {
            return BuzzStatusDescriptor(
                level: .buzzin,
                title: "Buzzin'",
                description: "Feeling yourself. Texts getting interesting."
            )
        }

        if effective < 2.6 {
            return BuzzStatusDescriptor(
                level: .wavy,
                title: "Wavy",
                description: "You're funnier than usual. Objectively."
            )
        }

        if effective < 3.8 {
            return BuzzStatusDescriptor(
                level: .onFire,
                title: "On fire",
                description: "Peak confidence. Decisions pending review."
            )
        }

        if effective < 5.0 {
            return BuzzStatusDescriptor(
                level: .tooLit,
                title: "Too lit",
                description: "Future you is already drafting an apology."
            )
        }

        return BuzzStatusDescriptor(
            level: .takeItEasyZone,
            title: "Take-it-easy zone",
            description: "Full send. Your liver filed a formal complaint."
        )
    }
}
