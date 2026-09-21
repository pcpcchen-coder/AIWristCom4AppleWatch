import Foundation

enum AgentClientError: LocalizedError {
    case missingGatewayURL
    case invalidHTTPResponse
    case server(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingGatewayURL:
            return "尚未設定 AIWrist Gateway URL"
        case .invalidHTTPResponse:
            return "Gateway 回應格式錯誤"
        case .server(let code, let message):
            return "Gateway 錯誤 \(code)：\(message)"
        case .invalidResponse:
            return "無法解析 AI 回覆"
        }
    }
}

final class AgentClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func query(_ text: String) async throws -> QueryResponse {
        guard let baseURL = AppConfig.gatewayBaseURL else {
            throw AgentClientError.missingGatewayURL
        }

        let endpoint = baseURL.appending(path: "api/v1/query")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = AppConfig.deviceToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(QueryRequest(text: text))

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AgentClientError.invalidHTTPResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw AgentClientError.server(http.statusCode, message)
        }

        guard let decoded = try? JSONDecoder().decode(QueryResponse.self, from: data) else {
            throw AgentClientError.invalidResponse
        }

        return decoded
    }
}
