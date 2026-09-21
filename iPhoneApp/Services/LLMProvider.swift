import Foundation

protocol LLMProvider {
    func query(text: String, locale: String) async throws -> String
}

enum CompanionLLMError: LocalizedError {
    case invalidGatewayURL
    case invalidHTTPResponse
    case server(Int, String)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidGatewayURL:
            return "iPhone 尚未設定有效的 LLM Gateway URL"
        case .invalidHTTPResponse:
            return "LLM Gateway 回應格式錯誤"
        case .server(let code, let message):
            return "LLM Gateway 錯誤 \(code)：\(message)"
        case .decodeFailed:
            return "無法解析 LLM 回覆"
        }
    }
}

/// v0.1 provider:
/// iPhone is the Watch-facing hub. The Codex host is behind the iPhone and is
/// replaceable. It can be a Mac during development or another always-on host.
final class RemoteCodexProvider: LLMProvider {
    private let settings: CompanionSettings
    private let session: URLSession

    init(
        settings: CompanionSettings = .shared,
        session: URLSession = .shared
    ) {
        self.settings = settings
        self.session = session
    }

    @MainActor
    private func configuration() throws -> (URL, String) {
        guard
            let baseURL = URL(string: settings.gatewayURL),
            let endpoint = URL(string: "api/v1/query", relativeTo: baseURL)?.absoluteURL
        else {
            throw CompanionLLMError.invalidGatewayURL
        }

        return (endpoint, settings.deviceToken)
    }

    func query(text: String, locale: String) async throws -> String {
        let (endpoint, token) = try await configuration()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(
            GatewayQueryRequest(
                text: text,
                locale: locale,
                sessionID: nil
            )
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw CompanionLLMError.invalidHTTPResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw CompanionLLMError.server(http.statusCode, message)
        }

        guard let decoded = try? JSONDecoder().decode(
            GatewayQueryResponse.self,
            from: data
        ) else {
            throw CompanionLLMError.decodeFailed
        }

        return decoded.reply
    }
}

actor CompanionLLMRouter {
    static let shared = CompanionLLMRouter()

    private let provider: LLMProvider

    init(provider: LLMProvider = RemoteCodexProvider()) {
        self.provider = provider
    }

    func query(text: String, locale: String) async throws -> String {
        try await provider.query(text: text, locale: locale)
    }
}
