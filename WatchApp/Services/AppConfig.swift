import Foundation

enum AppConfig {
    static var gatewayBaseURL: URL? {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "AIWRIST_GATEWAY_URL") as? String,
            !raw.isEmpty
        else {
            return nil
        }
        return URL(string: raw)
    }

    static var deviceToken: String? {
        guard
            let token = Bundle.main.object(forInfoDictionaryKey: "AIWRIST_DEVICE_TOKEN") as? String,
            !token.isEmpty
        else {
            return nil
        }
        return token
    }
}
