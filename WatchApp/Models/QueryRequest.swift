import Foundation

struct QueryRequest: Encodable {
    let text: String
    let device: String
    let locale: String
    let sessionID: String?

    enum CodingKeys: String, CodingKey {
        case text
        case device
        case locale
        case sessionID = "session_id"
    }

    init(text: String, sessionID: String? = nil) {
        self.text = text
        self.device = "apple_watch"
        self.locale = "zh-TW"
        self.sessionID = sessionID
    }
}
