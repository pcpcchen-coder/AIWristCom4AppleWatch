import Foundation

@MainActor
final class CompanionSettings: ObservableObject {
    static let shared = CompanionSettings()

    @Published var gatewayURL: String {
        didSet {
            UserDefaults.standard.set(gatewayURL, forKey: "gatewayURL")
        }
    }

    @Published var deviceToken: String {
        didSet {
            UserDefaults.standard.set(deviceToken, forKey: "deviceToken")
        }
    }

    private init() {
        self.gatewayURL = UserDefaults.standard.string(forKey: "gatewayURL")
            ?? "http://192.168.1.100:8000/"
        self.deviceToken = UserDefaults.standard.string(forKey: "deviceToken")
            ?? ""
    }
}
