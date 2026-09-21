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
