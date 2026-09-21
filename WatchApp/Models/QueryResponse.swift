import Foundation

struct QueryResponse: Decodable {
    let ok: Bool
    let requestID: String
    let reply: String
    let intent: String
    let speak: Bool
    let provider: String?
    let model: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case requestID = "request_id"
        case reply
        case intent
        case speak
        case provider
        case model
    }
}
