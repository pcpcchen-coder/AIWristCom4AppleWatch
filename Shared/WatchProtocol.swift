import Foundation

struct WatchQuery: Sendable, Equatable {
    let requestID: String
    let text: String
    let locale: String

    init(text: String, requestID: String = UUID().uuidString, locale: String = "zh-TW") throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: requestID) != nil, !trimmed.isEmpty,
              trimmed.count <= 4000, locale == "zh-TW" else { throw ProtocolError.invalidRequest }
        self.requestID = requestID
        self.text = trimmed
        self.locale = locale
    }

    init(message: [String: Any]) throws {
        guard message["type"] as? String == "query",
              let id = message["request_id"] as? String,
              let text = message["text"] as? String,
              let locale = message["locale"] as? String else { throw ProtocolError.invalidRequest }
        try self.init(text: text, requestID: id, locale: locale)
    }

    var message: [String: Any] {
        ["type": "query", "request_id": requestID, "text": text, "locale": locale]
    }
}

enum ProtocolError: LocalizedError, Sendable {
    case invalidRequest, invalidReply, timeout, cancelled, remote(String)
    var errorDescription: String? {
        switch self {
        case .invalidRequest: return "訊息格式錯誤或沒有文字"
        case .invalidReply: return "iPhone 回覆格式或編號錯誤"
        case .timeout: return "iPhone 未在時間內回覆，請重試"
        case .cancelled: return "已取消"
        case .remote(let message): return message
        }
    }
}

struct WatchReply: Sendable {
    let requestID: String
    let result: Result<String, ProtocolError>
    var message: [String: Any] {
        switch result {
        case .success(let text): return ["request_id": requestID, "reply": text]
        case .failure(let error): return ["request_id": requestID, "error": error.localizedDescription]
        }
    }
    static func decode(_ message: [String: Any], for requestID: String) throws -> String {
        guard message["request_id"] as? String == requestID else { throw ProtocolError.invalidReply }
        if let error = message["error"] as? String { throw ProtocolError.remote(error) }
        guard let text = message["reply"] as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProtocolError.invalidReply
        }
        return text
    }
}

/// WC callbacks, timeout and cancellation can race. Lock protects the sole terminal result.
final class ReplyLatch: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<String, Error>?
    private var continuation: CheckedContinuation<String, Error>?
    func install(_ continuation: CheckedContinuation<String, Error>) {
        lock.lock()
        if let result { lock.unlock(); continuation.resume(with: result); return }
        self.continuation = continuation
        lock.unlock()
    }
    func finish(_ result: Result<String, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}

protocol LLMProvider: Sendable {
    func query(text: String, locale: String) async throws -> String
}

struct FakeProvider: LLMProvider {
    enum Mode: Sendable { case success, failure, timeout }
    let mode: Mode
    init(mode: Mode = .success) { self.mode = mode }
    func query(text: String, locale: String) async throws -> String {
        switch mode {
        case .success: return "iPhone 已收到你的訊息"
        case .failure: throw ProtocolError.remote("測試用 provider 錯誤")
        case .timeout:
            try await Task.sleep(for: .seconds(60))
            throw ProtocolError.timeout
        }
    }
}

struct CompanionLLMRouter: Sendable {
    let provider: any LLMProvider
    func query(_ query: WatchQuery) async throws -> String {
        let answer = try await provider.query(text: query.text, locale: query.locale)
        guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProtocolError.invalidReply
        }
        return answer
    }
}
