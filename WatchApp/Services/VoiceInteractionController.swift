import Combine
import Foundation
import WatchKit

@MainActor
final class VoiceInteractionController: ObservableObject {
    @Published private(set) var state: AppState = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var lastReply = ""
    @Published private(set) var roundTrips = 0
    private let recognizer = SpeechRecognizer()
    private let phoneBridge = PhoneBridge.shared
    private let speechOutput = SpeechOutput()
    private var operation: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var generation = UUID()

    var primaryActionEnabled: Bool { state == .idle || state == .listening }
    var primaryActionTitle: String { state == .listening ? "停止並辨識" : "開始錄音" }
    var primaryActionSymbol: String { state == .listening ? "stop.fill" : "mic.fill" }

    /// One synchronous state change prevents duplicate tasks before the first await.
    func handlePrimaryAction() {
        switch state {
        case .idle:
            state = .preparing
            transcript = ""
            lastReply = ""
            let id = generation
            operation = Task {
                do {
                    try await recognizer.start()
                    guard id == generation, !Task.isCancelled else { recognizer.cancel(); return }
                    state = .listening
                    WKInterfaceDevice.current().play(.start)
                    timer = Task {
                        do { try await Task.sleep(for: .seconds(30)) } catch { return }
                        if state == .listening { handlePrimaryAction() }
                    }
                } catch { if id == generation { fail(error.localizedDescription) } }
            }
        case .listening:
            state = .transcribing
            timer?.cancel()
            WKInterfaceDevice.current().play(.click)
            let id = generation
            operation = Task {
                do {
                    let text = try await recognizer.stop()
                    guard id == generation, !Task.isCancelled else { return }
                    try await send(text, diagnostic: false, id: id)
                } catch { if id == generation { fail(error.localizedDescription) } }
            }
        default: break
        }
    }
    /// Real WatchConnectivity, fixed text only: never claims speech/model acceptance.
    func testConnection() {
        guard state == .idle else { return }
        state = .sending
        let id = generation
        operation = Task {
            do { try await send("連線測試", diagnostic: true, id: id) }
            catch { if id == generation { roundTrips = 0; fail(error.localizedDescription) } }
        }
    }
    private func send(_ text: String, diagnostic: Bool, id: UUID) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProtocolError.invalidRequest
        }
        transcript = text
        state = .sending
        let reply = try await phoneBridge.ask(text)
        guard id == generation, !Task.isCancelled else { return }
        if diagnostic {
            guard reply == "iPhone 已收到你的訊息" else { throw ProtocolError.invalidReply }
            roundTrips += 1
        }
        lastReply = reply
        WKInterfaceDevice.current().play(.success)
        try await speakReply()
    }
    func replay() {
        guard state == .idle, !lastReply.isEmpty else { return }
        state = .speaking
        let id = generation
        operation = Task {
            do { try await speakReply() }
            catch { if id == generation { fail(error.localizedDescription) } }
        }
    }
    private func speakReply() async throws {
        state = .speaking
        let id = generation
        try await speechOutput.speak(lastReply) { [weak self] in
            guard let self, id == self.generation else { return }
            self.timer?.cancel()
            self.state = .idle
        }
        timer?.cancel()
        timer = Task {
            do { try await Task.sleep(for: .seconds(45)) } catch { return }
            if state == .speaking { fail("朗讀逾時，請重試") }
        }
    }
    func resetError() {
        generation = UUID()
        operation?.cancel()
        timer?.cancel()
        recognizer.cancel()
        speechOutput.stop()
        transcript = ""
        state = .idle
    }
    func sceneDidEnterBackground() { resetError(); roundTrips = 0 }
    private func fail(_ message: String) {
        timer?.cancel()
        recognizer.cancel()
        speechOutput.stop()
        WKInterfaceDevice.current().play(.failure)
        state = .error(message)
    }
}
