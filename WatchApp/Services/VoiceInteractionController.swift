import Combine
import Foundation
import WatchKit

@MainActor
final class VoiceInteractionController: ObservableObject {
    @Published private(set) var state: AppState = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var lastReply = ""

    private let recognizer = SpeechRecognizer()
    private let phoneBridge = PhoneBridge.shared
    private let speechOutput = SpeechOutput()

    var primaryActionEnabled: Bool {
        switch state {
        case .idle, .listening:
            return true
        case .transcribing, .sending, .speaking, .error:
            return false
        }
    }

    var primaryActionTitle: String {
        switch state {
        case .listening:
            return "完成並送出"
        default:
            return "開始說話"
        }
    }

    var primaryActionSymbol: String {
        switch state {
        case .listening:
            return "stop.fill"
        default:
            return "mic.fill"
        }
    }

    /// Called by both a physical screen tap and watchOS Double Tap.
    func handlePrimaryAction() {
        switch state {
        case .idle:
            Task { await startListening() }

        case .listening:
            Task { await finishListeningAndSend() }

        default:
            break
        }
    }

    func resetError() {
        recognizer.cancel()
        speechOutput.stop()
        transcript = ""
        state = .idle
    }

    private func startListening() async {
        do {
            transcript = ""
            lastReply = ""
            try await recognizer.start { [weak self] partial in
                self?.transcript = partial
            }
            state = .listening
            WKInterfaceDevice.current().play(.start)
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func finishListeningAndSend() async {
        WKInterfaceDevice.current().play(.click)
        state = .transcribing

        let text = await recognizer.stop()
        transcript = text

        guard !text.isEmpty else {
            fail("沒有辨識到語音，請再試一次")
            return
        }

        state = .sending

        do {
            let reply = try await phoneBridge.ask(text)
            lastReply = reply
            state = .speaking
            WKInterfaceDevice.current().play(.success)

            speechOutput.speak(reply) { [weak self] in
                Task { @MainActor in
                    self?.state = .idle
                }
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func fail(_ message: String) {
        recognizer.cancel()
        speechOutput.stop()
        WKInterfaceDevice.current().play(.failure)
        state = .error(message)
    }
}
