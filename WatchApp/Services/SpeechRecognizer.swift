import AVFoundation
import Foundation
import Speech

enum SpeechRecognizerError: LocalizedError {
    case microphonePermissionDenied
    case speechPermissionDenied
    case recognizerUnavailable
    case audioStartFailed

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "請允許麥克風權限"
        case .speechPermissionDenied:
            return "請允許語音辨識權限"
        case .recognizerUnavailable:
            return "目前無法使用語音辨識"
        case .audioStartFailed:
            return "無法啟動麥克風"
        }
    }
}

@MainActor
final class SpeechRecognizer {
    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))

    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private(set) var latestText = ""

    func requestPermissions() async throws {
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            throw SpeechRecognizerError.microphonePermissionDenied
        }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            throw SpeechRecognizerError.speechPermissionDenied
        }
    }

    func start(onPartialResult: @escaping @MainActor (String) -> Void) async throws {
        try await requestPermissions()

        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecognizerError.recognizerUnavailable
        }

        stopAudioOnly()
        latestText = ""

        let audioRequest = SFSpeechAudioBufferRecognitionRequest()
        audioRequest.shouldReportPartialResults = true
        request = audioRequest

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try await session.setActive(true)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { [weak audioRequest] buffer, _ in
            audioRequest?.append(buffer)
        }

        task = recognizer.recognitionTask(with: audioRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    let text = result.bestTranscription.formattedString
                    self.latestText = text
                    onPartialResult(text)
                }

                if error != nil {
                    self.stopAudioOnly()
                }
            }
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            stopAudioOnly()
            throw SpeechRecognizerError.audioStartFailed
        }
    }

    func stop() async -> String {
        stopAudioOnly()
        request?.endAudio()

        // Give Speech a short moment to deliver the final transcription.
        try? await Task.sleep(for: .milliseconds(350))

        let result = latestText.trimmingCharacters(in: .whitespacesAndNewlines)
        task?.cancel()
        task = nil
        request = nil

        try? await AVAudioSession.sharedInstance().setActive(false)

        return result
    }

    func cancel() {
        stopAudioOnly()
        task?.cancel()
        task = nil
        request = nil
        latestText = ""
    }

    private func stopAudioOnly() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
    }
}
