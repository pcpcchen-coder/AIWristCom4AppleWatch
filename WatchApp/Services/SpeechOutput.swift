import AVFoundation
import Foundation

@MainActor
final class SpeechOutput: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var completion: (@MainActor () -> Void)?
    private var generation = UUID()
    private var utterance: AVSpeechUtterance?
    override init() { super.init(); synthesizer.delegate = self }
    func speak(_ text: String, completion: @escaping @MainActor () -> Void) async throws {
        stop()
        let id = generation
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.activate(options: []) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume() }
                else { continuation.resume(throwing: ProtocolError.remote("無法啟動朗讀音訊")) }
            }
        }
        guard id == generation else { throw CancellationError() }
        do { try Task.checkCancellation() }
        catch { try? session.setActive(false); throw error }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW")
        utterance.rate = 0.48
        self.utterance = utterance
        self.completion = completion
        synthesizer.speak(utterance)
    }
    func stop() {
        generation = UUID()
        completion = nil
        utterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    private func finished(_ id: ObjectIdentifier) {
        guard let utterance, ObjectIdentifier(utterance) == id else { return }
        let done = completion
        completion = nil
        self.utterance = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        done?()
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finished(id) }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finished(id) }
    }
}
