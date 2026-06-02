import WatchConnectivity
import Foundation

final class WatchSession: NSObject, WCSessionDelegate {
    static let shared = WatchSession()
    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendVerify(habitID: String) {
        WatchHabitStore.shared.markVerified(habitID: habitID)
        let message = ["action": "verify", "habitID": habitID]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(message)
            }
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {}

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: applicationContext),
              let payload = try? JSONDecoder().decode(WatchPayload.self, from: data) else { return }
        DispatchQueue.main.async {
            WatchHabitStore.shared.update(from: payload)
        }
    }
}
