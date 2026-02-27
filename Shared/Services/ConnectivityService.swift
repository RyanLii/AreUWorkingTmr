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

// MARK: - Shared encoding / decoding helpers (pure Foundation — no WCSession)

enum WCMessageCoding {
    static func buildPayload(type: WCMsgType, data: Data? = nil) -> [String: Any] {
        var msg: [String: Any] = ["t": type.rawValue]
        if let data { msg["p"] = data.base64EncodedString() }
        return msg
    }

    static func decode<T: Decodable>(from message: [String: Any]) -> T? {
        guard let base64 = message["p"] as? String,
              let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func parseType(from message: [String: Any]) -> WCMsgType? {
        guard let raw = message["t"] as? String else { return nil }
        return WCMsgType(rawValue: raw)
    }
}
