import Foundation
import WatchConnectivity

final class WatchConnectivityManager: NSObject, ObservableObject {
    @MainActor weak var store: AppStore?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Send helpers

    private func sendMessage(type: WCMsgType, payload: Data? = nil) {
        guard WCSession.default.activationState == .activated else { return }

        var msg: [String: Any] = ["t": type.rawValue]
        if let data = payload {
            msg["p"] = data.base64EncodedString()
        }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(msg, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(msg)
            }
        } else {
            WCSession.default.transferUserInfo(msg)
        }
    }

    // MARK: - Handle incoming messages

    @MainActor
    private func handleMessage(_ message: [String: Any]) {
        guard let store,
              let typeStr = message["t"] as? String,
              let type = WCMsgType(rawValue: typeStr) else { return }

        switch type {
        case .drinksAdded:
            if let entries: [DrinkEntry] = decode(from: message) {
                store.applyRemoteDrinks(entries)
            }
        case .drinksDeleted:
            if let uuidStrings: [String] = decode(from: message) {
                store.applyRemoteDelete(Set(uuidStrings.compactMap(UUID.init)))
            }
        case .profileUpdated:
            if let profile: UserProfile = decode(from: message) {
                store.applyRemoteProfile(profile)
            }
        case .doneTonight:
            store.applyRemoteDoneTonight()
        case .fullContext:
            if let payload: ContextPayload = decode(from: message) {
                store.applyRemoteDrinks(payload.entries)
                store.applyRemoteProfile(payload.profile)
                if payload.hasMarkedDoneTonight {
                    store.applyRemoteDoneTonight()
                }
            }
        case .contextRequest:
            break // Watch doesn't serve context
        }
    }

    private func decode<T: Decodable>(from message: [String: Any]) -> T? {
        guard let base64 = message["p"] as? String,
              let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - ConnectivityService

extension WatchConnectivityManager: ConnectivityService {
    func sendDrinksAdded(_ entries: [DrinkEntry]) {
        sendMessage(type: .drinksAdded, payload: try? JSONEncoder().encode(entries))
    }

    func sendDrinksDeleted(_ ids: Set<UUID>) {
        sendMessage(type: .drinksDeleted, payload: try? JSONEncoder().encode(Array(ids).map(\.uuidString)))
    }

    func sendProfileUpdated(_ profile: UserProfile) {
        sendMessage(type: .profileUpdated, payload: try? JSONEncoder().encode(profile))
    }

    func sendDoneTonight() {
        sendMessage(type: .doneTonight)
    }

    func sendFullContext() {
        // Watch does not initiate full-context pushes; no-op.
    }

    func requestContext() {
        sendMessage(type: .contextRequest)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in self.requestContext() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.handleMessage(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.handleMessage(userInfo) }
    }
}
