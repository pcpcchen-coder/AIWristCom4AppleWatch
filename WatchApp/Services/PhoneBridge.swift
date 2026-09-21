import Foundation
import WatchConnectivity

@MainActor
final class PhoneBridge: NSObject, WCSessionDelegate {
    static let shared = PhoneBridge()
    private let session = WCSession.default
    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func ask(_ text: String, locale: String = "zh-TW") async throws -> String {
        guard WCSession.isSupported(), session.activationState == .activated else {
            throw ProtocolError.remote("尚未連接 iPhone companion，請稍後重試")
        }
        guard session.isCompanionAppInstalled else {
            throw ProtocolError.remote("請先在配對 iPhone 安裝 Companion")
        }
        guard session.isReachable else {
            throw ProtocolError.remote("找不到 iPhone，請確認連線並開啟 Companion")
        }
        let query = try WatchQuery(text: text, locale: locale)
        let latch = ReplyLatch()
        let deadline = Task {
            do { try await Task.sleep(for: .seconds(30)) }
            catch { return }
            latch.finish(.failure(ProtocolError.timeout))
        }
        defer { deadline.cancel() }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                latch.install(continuation)
                session.sendMessage(query.message, replyHandler: { message in
                    latch.finish(Result { try WatchReply.decode(message, for: query.requestID) })
                }, errorHandler: { _ in
                    latch.finish(.failure(ProtocolError.remote("iPhone 連線中斷，請重試")))
                })
            }
        } onCancel: {
            latch.finish(.failure(CancellationError()))
        }
    }

    nonisolated func session(_ session: WCSession,
                            activationDidCompleteWith activationState: WCSessionActivationState,
                            error: Error?) {}
}
