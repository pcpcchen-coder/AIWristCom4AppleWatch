import Foundation

struct RemoteCodexProvider: LLMProvider {
    let endpoint: URL
    let token: String
    let session: URLSession

    init(baseURL: String, token: String, session: URLSession = .shared) throws {
        guard let url = URL(string: baseURL), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw ProtocolError.remote("請在 iPhone 設定有效的 HTTPS Gateway URL")
        }
        self.endpoint = url.appendingPathComponent("api/v1/query")
        self.token = token
        self.session = session
    }

    func query(text: String, locale: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(GatewayQueryRequest(text: text, locale: locale, sessionID: nil))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProtocolError.invalidReply }
        guard (200..<300).contains(http.statusCode) else {
            let message: String
            switch http.statusCode {
            case 401: message = "請在 iPhone 檢查 Device token，並在 provider host 確認 ChatGPT 登入"
            case 429: message = "訂閱額度或請求頻率受限，請稍後重試"
            case 504: message = "AI 服務逾時，請稍後重試"
            default: message = "AI 服務暫時無法使用（\(http.statusCode)）"
            }
            throw ProtocolError.remote(message)
        }
        guard let decoded = try? JSONDecoder().decode(GatewayQueryResponse.self, from: data),
              decoded.ok, !decoded.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProtocolError.invalidReply
        }
        return decoded.reply
    }
}
