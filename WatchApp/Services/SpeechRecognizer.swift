import AVFoundation
import Foundation

/// No Speech framework exists in the watchOS SDK. A local engine must be qualified
/// on hardware before replacing this explicit unavailable implementation.
protocol LocalTranscriber: Sendable {
    func transcribe(file: URL, locale: String) async throws -> String
}
struct UnavailableLocalTranscriber: LocalTranscriber {
    func transcribe(file: URL, locale: String) async throws -> String {
        throw ProtocolError.remote("錄音已停止。本地繁中 STT 引擎尚未接入；請先使用固定文字連線測試。")
    }
}

@MainActor
final class SpeechRecognizer {
    private var recorder: AVAudioRecorder?
    private var file: URL?
    private let transcriber: any LocalTranscriber
    init(transcriber: any LocalTranscriber = UnavailableLocalTranscriber()) {
        self.transcriber = transcriber
    }
    func start() async throws {
        cancel()
        guard await AVAudioApplication.requestRecordPermission() else {
            throw ProtocolError.remote("請在 Watch 設定允許麥克風權限")
        }
        try Task.checkCancellation()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        // Watch audio activation is asynchronous and must use activate(options:).
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.activate(options: []) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume() }
                else { continuation.resume(throwing: ProtocolError.remote("無法啟動麥克風")) }
            }
        }
        do {
            try Task.checkCancellation()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
            file = url
            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ])
            self.recorder = recorder
            guard recorder.record() else { throw ProtocolError.remote("無法開始錄音") }
        } catch { cancel(); throw error }
    }
    func stop() async throws -> String {
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        guard let file else { throw ProtocolError.remote("沒有錄音") }
        defer { try? FileManager.default.removeItem(at: file); self.file = nil }
        return try await transcriber.transcribe(file: file, locale: "zh-TW")
    }
    func cancel() {
        recorder?.stop()
        recorder = nil
        if let file { try? FileManager.default.removeItem(at: file) }
        file = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
