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
                title: "Low logged load",
                description: "Low trend from your entries."
            )
        }

        if effective < 0.8 {
            return BuzzStatusDescriptor(
                level: .goodVibes,
                title: "Light session",
                description: "Light trend from your log entries."
            )
        }

        if effective < 1.6 {
            return BuzzStatusDescriptor(
                level: .buzzin,
                title: "Mid session",
                description: "Mid-range trend from your log entries."
            )
        }

        if effective < 2.6 {
            return BuzzStatusDescriptor(
                level: .wavy,
                title: "Active session",
                description: "Session trend above two-drink range."
            )
        }

        if effective < 3.8 {
            return BuzzStatusDescriptor(
                level: .onFire,
                title: "Elevated session",
                description: "Session load trend is elevated."
            )
        }

        if effective < 5.0 {
            return BuzzStatusDescriptor(
                level: .tooLit,
                title: "Heavy load",
                description: "High load. Wind-down mode recommended."
            )
        }

        return BuzzStatusDescriptor(
            level: .takeItEasyZone,
            title: "High load zone",
            description: "Very high load. Pause drinks and prioritize rest."
        )
    }
}
