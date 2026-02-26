import Foundation

// MARK: - Protocol

protocol ConnectivityService: AnyObject {
    func sendDrinksAdded(_ entries: [DrinkEntry])
    func sendDrinksDeleted(_ ids: Set<UUID>)
    func sendProfileUpdated(_ profile: UserProfile)
    func sendDoneTonight()
    func sendFullContext()
    func sendClearAll()
    func requestContext()
}

// MARK: - Message format

enum WCMsgType: String {
    case drinksAdded    = "da"
    case drinksDeleted  = "dd"
    case profileUpdated = "pu"
    case doneTonight    = "dt"
    case contextRequest = "cr"
    case fullContext    = "fc"
    case clearAll       = "ca"
}

struct ContextPayload: Codable {
    let entries: [DrinkEntry]
    let profile: UserProfile
    let hasMarkedDoneTonight: Bool
}
