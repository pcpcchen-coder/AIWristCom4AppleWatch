import Combine
import Foundation
import UIKit
import WatchConnectivity

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    @Published private(set) var isPaired = false
    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var lastRequest: String = ""
    @Published private(set) var lastReply: String = ""
    @Published private(set) var lastError: String = ""

    private let session: WCSession

    private override init() {
        self.session = WCSession.default
        super.init()

        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.activationState = activationState
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            if let error {
                self.lastError = error.localizedDescription
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// Apple delivers this when the foreground Watch sends sendMessage(...).
    /// The Watch-side call can wake the companion iOS app in the background.
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard
            message["type"] as? String == "query",
            let requestID = message["request_id"] as? String,
            let text = message["text"] as? String,
            !text.isEmpty
        else {
            replyHandler([
                "error": "Invalid Watch request"
            ])
            return
        }

        let locale = message["locale"] as? String ?? "zh-TW"

        Task {
            let backgroundID = await MainActor.run {
                UIApplication.shared.beginBackgroundTask(
                    withName: "AIWristLLMQuery"
                )
            }

            defer {
                Task { @MainActor in
                    if backgroundID != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundID)
                    }
                }
            }

            await MainActor.run {
                self.lastRequest = text
                self.lastError = ""
            }

            do {
                let answer = try await CompanionLLMRouter.shared.query(
                    text: text,
                    locale: locale
                )

                await MainActor.run {
                    self.lastReply = answer
                }

                replyHandler([
                    "request_id": requestID,
                    "reply": answer
                ])
            } catch {
                let message = error.localizedDescription

                await MainActor.run {
                    self.lastError = message
                }

                replyHandler([
                    "request_id": requestID,
                    "error": message
                ])
            }
        }
    }
}
