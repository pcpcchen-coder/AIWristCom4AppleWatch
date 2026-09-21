import Combine
import Foundation
import Security

@MainActor
final class CompanionSettings: ObservableObject {
    static let shared = CompanionSettings()
    enum Provider: String, CaseIterable, Identifiable {
        case mock, mockError, mockTimeout, remote
        var id: String { rawValue }
        var title: String {
            switch self {
            case .mock: return "固定回覆（先驗收）"
            case .mockError: return "測試錯誤"
            case .mockTimeout: return "測試逾時"
            case .remote: return "Remote Codex（驗收後）"
            }
        }
    }
    // Each launch starts with mock, so no model is contacted during connectivity setup.
    @Published var provider: Provider = .mock
    @Published var connectivityAccepted = false
    @Published var gatewayURL: String {
        didSet { UserDefaults.standard.set(gatewayURL, forKey: "gatewayURL") }
    }
    @Published var deviceToken: String
    @Published private(set) var credentialError = ""
    private let key: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "AIWristCompanion", kSecAttrAccount as String: "deviceToken"]
    private init() {
        gatewayURL = UserDefaults.standard.string(forKey: "gatewayURL") ?? ""
        deviceToken = ""
        var query = key
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data { deviceToken = String(decoding: data, as: UTF8.self) }
        // Remove the previous scaffold's plaintext secret; enter it again in this UI.
        UserDefaults.standard.removeObject(forKey: "deviceToken")
    }
    func saveToken() {
        let data = Data(deviceToken.utf8)
        var status = SecItemUpdate(key as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = key
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        credentialError = status == errSecSuccess ? "" : "無法儲存憑證（\(status)）"
    }
    func router() throws -> CompanionLLMRouter {
        switch provider {
        case .mock: return CompanionLLMRouter(provider: FakeProvider())
        case .mockError: return CompanionLLMRouter(provider: FakeProvider(mode: .failure))
        case .mockTimeout: return CompanionLLMRouter(provider: FakeProvider(mode: .timeout))
        case .remote:
            guard connectivityAccepted else { throw ProtocolError.remote("請先完成 Watch↔iPhone 固定回覆 10 次驗收") }
            return CompanionLLMRouter(provider: try RemoteCodexProvider(baseURL: gatewayURL, token: deviceToken))
        }
    }
}
