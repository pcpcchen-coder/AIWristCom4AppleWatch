import SwiftUI

struct ContentView: View {
    @StateObject private var controller = VoiceInteractionController()

    var body: some View {
        VStack(spacing: 10) {
            Text("小克")
                .font(.headline)

            content

            primaryActionButton
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch controller.state {
        case .idle:
            if controller.lastReply.isEmpty {
                Text("抬手後 Double Tap")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                Text(controller.lastReply)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
            }

        case .listening:
            VStack(spacing: 4) {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative)
                    .font(.title2)

                Text(
                    controller.transcript.isEmpty
                    ? "聆聽中…"
                    : controller.transcript
                )
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            }

        case .transcribing, .sending:
            VStack(spacing: 6) {
                ProgressView()
                Text(controller.state.statusText)
                    .font(.caption2)
            }

        case .speaking:
            VStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title3)
                Text(controller.lastReply)
                    .font(.caption2)
                    .lineLimit(4)
            }

        case .error(let message):
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                Text(message)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)

                Button("重設") {
                    controller.resetError()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var primaryActionButton: some View {
        Button {
            controller.handlePrimaryAction()
        } label: {
            Label(
                controller.primaryActionTitle,
                systemImage: controller.primaryActionSymbol
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        // watchOS 11+: index finger + thumb Double Tap triggers this button.
        .handGestureShortcut(
            .primaryAction,
            isEnabled: controller.primaryActionEnabled
        )
        .disabled(!controller.primaryActionEnabled)
        .accessibilityLabel(controller.primaryActionTitle)
        .accessibilityHint("支援 Apple Watch Double Tap 手勢")
    }
}

#Preview {
    ContentView()
}
