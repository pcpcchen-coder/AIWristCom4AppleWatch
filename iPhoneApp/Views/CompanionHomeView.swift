import SwiftUI

struct CompanionHomeView: View {
    @EnvironmentObject private var watchSession: WatchSessionManager
    @EnvironmentObject private var settings: CompanionSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("Apple Watch") {
                    LabeledContent(
                        "Session",
                        value: watchSession.activationState == .activated
                            ? "Active"
                            : "Inactive"
                    )
                    LabeledContent(
                        "Paired",
                        value: watchSession.isPaired ? "Yes" : "No"
                    )
                    LabeledContent(
                        "Watch App",
                        value: watchSession.isWatchAppInstalled
                            ? "Installed"
                            : "Not Installed"
                    )
                }

                Section("LLM Provider") {
                    Picker("Provider", selection: $settings.provider) {
                        ForEach(CompanionSettings.Provider.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }
                    LabeledContent("iPhone 已回覆 mock 次數", value: "\(watchSession.mockReplies)")
                    Toggle("已在 Watch 端確認連續 10 次收到回覆", isOn: $settings.connectivityAccepted)
                    Text("此計數只代表 iPhone 已送回；請以 Watch 畫面、TTS 與驗收表確認真正往返成功。")
                        .font(.footnote)
                    TextField(
                        "Gateway URL",
                        text: $settings.gatewayURL
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    SecureField(
                        "Device token (optional)",
                        text: $settings.deviceToken
                    )

                    Button("儲存 Token 至鑰匙圈") { settings.saveToken() }
                    if !settings.credentialError.isEmpty { Text(settings.credentialError) }
                    Text(
                        "v0.1：iPhone 是 Watch 的唯一近端 Hub；"
                        + "Codex Gateway 位於 iPhone 後方，可替換。"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if !watchSession.lastRequest.isEmpty {
                    Section("Last Watch Request") {
                        Text(watchSession.lastRequest)
                    }
                }

                if !watchSession.lastReply.isEmpty {
                    Section("Last AI Reply") {
                        Text(watchSession.lastReply)
                    }
                }

                if !watchSession.lastError.isEmpty {
                    Section("Error") {
                        Text(watchSession.lastError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("AIWrist Companion")
        }
    }
}

#Preview {
    CompanionHomeView()
        .environmentObject(WatchSessionManager.shared)
        .environmentObject(CompanionSettings.shared)
}
