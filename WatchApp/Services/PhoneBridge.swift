import Foundation
import WatchConnectivity

enum PhoneBridgeError: LocalizedError {
    case unsupported
    case notActivated
    case invalidReply
    case phoneError(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "這支 Apple Watch 無法使用 WatchConnectivity"
        case .notActivated:
            return "尚未連接 iPhone companion app"
        case .invalidReply:
            return "iPhone 回傳格式錯誤"
        case .phoneError(let message):
            return message
        }
    }
}

/// The Watch never talks to an LLM server directly.
/// Interactive requests always go through the paired iPhone companion app.
final class PhoneBridge: NSObject, WCSessionDelegate {
    static let shared = PhoneBridge()

    private let session: WCSession

    private override init() {
        self.session = WCSession.default
        super.init()

        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func ask(_ text: String, locale: String = "zh-TW") async throws -> String {
        guard WCSession.isSupported() else {
            throw PhoneBridgeError.unsupported
        }

        guard session.activationState == .activated else {
            throw PhoneBridgeError.notActivated
        }

        let requestID = UUID().uuidString

        let message: [String: Any] = [
            "type": "query",
            "request_id": requestID,
            "text": text,
            "locale": locale
        ]

        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(
                message,
                replyHandler: { reply in
                    if let error = reply["error"] as? String {
                        continuation.resume(
                            throwing: PhoneBridgeError.phoneError(error)
                        )
                        return
                    }

                    guard
                        let replyRequestID = reply["request_id"] as? String,
                        replyRequestID == requestID,
                        let answer = reply["reply"] as? String,
                        !answer.isEmpty
                    else {
                        continuation.resume(
                            throwing: PhoneBridgeError.invalidReply
                        )
                        return
                    }

                    continuation.resume(returning: answer)
                },
                errorHandler: { error in
                    continuation.resume(
                        throwing: PhoneBridgeError.phoneError(
                            "無法連到 iPhone：\(error.localizedDescription)"
                        )
                    )
                }
            )
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // v0.1: state is checked at send time.
    }
}
