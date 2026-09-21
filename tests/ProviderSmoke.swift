import Foundation

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let code = Int(request.url!.host!.split(separator: ".")[0]) ?? 200
        let body: String
        switch code {
        case 201: body = "not-json"
        case 202: body = #"{"ok":false,"request_id":"id","reply":"text","intent":"general_chat","speak":true}"#
        case 203: body = #"{"ok":true,"request_id":"id","reply":" ","intent":"general_chat","speak":true}"#
        default: body = #"{"ok":true,"request_id":"id","reply":"繁中回覆","intent":"general_chat","speak":true}"#
        }
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-only")
        precondition(request.url!.path == "/base/api/v1/query")
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct ProviderSmoke {
    static func main() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        for code in [200, 201, 202, 203, 401, 429, 500, 504] {
            let provider = try RemoteCodexProvider(baseURL: "https://\(code).example.test/base", token: "test-only", session: session)
            do {
                let answer = try await provider.query(text: "測試", locale: "zh-TW")
                precondition(code == 200 && answer == "繁中回覆")
            } catch { precondition(code != 200, "Unexpected success-case failure") }
        }
        for base in ["http://example.test", "not a url", "https://user:secret@example.test", "https://example.test/?query=x"] {
            do { _ = try RemoteCodexProvider(baseURL: base, token: ""); fatalError("Invalid URL accepted") }
            catch {}
        }
        print("PASS: 8 HTTP response cases + 4 URL validation cases; URLProtocol stub, no network")
    }
}
