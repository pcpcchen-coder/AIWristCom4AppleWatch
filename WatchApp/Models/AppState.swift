import Foundation

enum AppState: Equatable {
    case idle
    case listening
    case transcribing
    case sending
    case speaking
    case error(String)

    var statusText: String {
        switch self {
        case .idle:
            return "雙指互點兩下開始說話"
        case .listening:
            return "聆聽中，再 Double Tap 送出"
        case .transcribing:
            return "語音辨識中…"
        case .sending:
            return "AI 思考中…"
        case .speaking:
            return "小克回答中…"
        case .error(let message):
            return message
        }
    }
}
