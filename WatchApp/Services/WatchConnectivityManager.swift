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
        let msg = WCMessageCoding.buildPayload(type: type, data: payload)
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
              let type = WCMessageCoding.parseType(from: message) else { return }

        switch type {
        case .drinksAdded:
            if let entries: [DrinkEntry] = WCMessageCoding.decode(from: message) {
                store.applyRemoteDrinks(entries)
            }
        case .drinksDeleted:
            if let uuidStrings: [String] = WCMessageCoding.decode(from: message) {
                store.applyRemoteDelete(Set(uuidStrings.compactMap(UUID.init)))
            }
        case .profileUpdated:
            if let profile: UserProfile = WCMessageCoding.decode(from: message) {
                store.applyRemoteProfile(profile)
            }
        case .doneTonight:
            store.applyRemoteDoneTonight()
        case .fullContext:
            if let payload: ContextPayload = WCMessageCoding.decode(from: message) {
                store.applyFullContext(payload)
            }
        case .clearAll:
            store.clearAllData()
        case .contextRequest:
            break // Watch doesn't serve context
        }
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

    func sendClearAll() {
        // Watch does not initiate clear; no-op.
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
