import Combine
import Foundation
import UIKit
import WatchConnectivity

/// The legacy WC reply block is transferred once; it is invoked only by MainActor work.
private final class ReplyChannel: @unchecked Sendable {
    let callback: ([String: Any]) -> Void
    init(_ callback: @escaping ([String: Any]) -> Void) { self.callback = callback }
}

@MainActor
private final class PendingReply {
    let id: String
    private var channel: ReplyChannel?
    var task: Task<Void, Never>?
    var deadline: Task<Void, Never>?
    var backgroundID: UIBackgroundTaskIdentifier = .invalid
    init(id: String, channel: ReplyChannel) { self.id = id; self.channel = channel }
    @discardableResult
    func finish(_ result: Result<String, ProtocolError>) -> Bool {
        guard let channel else { return false }
        self.channel = nil
        channel.callback(WatchReply(requestID: id, result: result).message)
        task?.cancel()
        deadline?.cancel()
        task = nil
        deadline = nil
        if backgroundID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundID)
            backgroundID = .invalid
        }
        return true
    }
}

@MainActor
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()
    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    @Published private(set) var isPaired = false
    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var lastRequest = ""
    @Published private(set) var lastReply = ""
    @Published private(set) var lastError = ""
    @Published private(set) var mockReplies = 0
    private let session = WCSession.default
    private var pending: PendingReply?
    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }
    private func refresh() {
        activationState = session.activationState
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
    }
    nonisolated func session(_ session: WCSession,
                            activationDidCompleteWith activationState: WCSessionActivationState,
                            error: Error?) {
        let message = error?.localizedDescription
        Task { @MainActor in self.refresh(); self.lastError = message ?? "" }
    }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.refresh() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in self.refresh() }
    }
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self.pending?.finish(.failure(.remote("配對的 Watch 已變更")))
            self.pending = nil
            self.mockReplies = 0
            CompanionSettings.shared.connectivityAccepted = false
            self.session.activate()
            self.refresh()
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                            replyHandler: @escaping ([String: Any]) -> Void) {
        let id = message["request_id"] as? String ?? ""
        guard let query = try? WatchQuery(message: message) else {
            replyHandler(WatchReply(requestID: id, result: .failure(.invalidRequest)).message)
            return
        }
        let channel = ReplyChannel(replyHandler)
        Task { @MainActor in self.receive(query, channel: channel) }
    }
    private func receive(_ query: WatchQuery, channel: ReplyChannel) {
        guard pending == nil else {
            channel.callback(WatchReply(requestID: query.requestID, result: .failure(.remote("iPhone 正在處理上一個請求"))).message)
            return
        }
        let request = PendingReply(id: query.requestID, channel: channel)
        pending = request
        lastRequest = query.text
        lastError = ""
        lastReply = ""
        request.backgroundID = UIApplication.shared.beginBackgroundTask(withName: "AIWristQuery") {
            Task { @MainActor in self.complete(request, result: .failure(.remote("iPhone 背景處理時間已結束")), mock: false) }
        }
        request.deadline = Task {
            do { try await Task.sleep(for: .seconds(27)) } catch { return }
            self.complete(request, result: .failure(.timeout), mock: false)
        }
        let mock = CompanionSettings.shared.provider == .mock
        request.task = Task {
            do {
                let router = try CompanionSettings.shared.router()
                let answer = try await router.query(query)
                self.complete(request, result: .success(answer), mock: mock)
            } catch {
                self.complete(request, result: .failure(.remote(error.localizedDescription)), mock: false)
            }
        }
    }
    private func complete(_ request: PendingReply, result: Result<String, ProtocolError>, mock: Bool) {
        guard request.finish(result) else { return }
        pending = nil
        switch result {
        case .success(let answer): lastReply = answer; if mock { mockReplies += 1 }
        case .failure(let error): lastError = error.localizedDescription; mockReplies = 0
        }
    }
}
