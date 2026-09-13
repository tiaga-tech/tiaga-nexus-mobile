//
//  ChatComposerBar.swift
//  TIAGA
//

import SwiftUI

/// The shared text-input-and-send control for both the orchestrator Chat and
/// Agent Chat. Text only — no microphone button; voice is out of scope for
/// this app even though the desktop client is voice-first. Matches the real
/// product's text-mode composer: a glass bar with a filled "Send" button that
/// dims (not disappears) when there's nothing to send.
///
/// `isStreaming`/`onStop` are Chat-only (the orchestrator's in-flight turn
/// can be cancelled via `POST /api/cancel`) — Agent Chat doesn't pass them,
/// so its composer stays plain Send-only, matching its own separate
/// stop-a-running-agent mechanism (Section 6's `CancelAgentTaskUseCase`,
/// a device-row action, not a composer button).
struct ChatComposerBar: View {
    @Binding var text: String
    let isSendDisabled: Bool
    var isStreaming: Bool = false
    let onSend: () -> Void
    var onStop: () -> Void = {}

    var body: some View {
        HStack(alignment: .bottom, spacing: TIAGASpacing.sm) {
            TextField(
                "",
                text: $text,
                prompt: Text("Message TIAGA…").foregroundStyle(TIAGAColor.textTertiary),
                axis: .vertical
            )
                .font(TIAGATypography.body)
                .foregroundStyle(TIAGAColor.textPrimary)
                .padding(.horizontal, TIAGASpacing.sm)
                .padding(.vertical, TIAGASpacing.sm)

            Button(isStreaming ? "Stop" : "Send", action: isStreaming ? onStop : onSend)
                .font(TIAGATypography.body)
                .foregroundStyle(TIAGAColor.textOnAccent)
                .padding(.horizontal, TIAGASpacing.md)
                .padding(.vertical, TIAGASpacing.sm)
                .background(
                    (isStreaming ? TIAGAColor.statusDanger : TIAGAColor.brandAccent)
                        .opacity(isStreaming ? 0.8 : (isSendDisabled ? 0.3 : 0.8))
                )
                .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.md, style: .continuous))
                .disabled(!isStreaming && isSendDisabled)
        }
        .padding(TIAGASpacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous)
                .strokeBorder(TIAGAColor.border, lineWidth: 1)
        )
    }
}

#Preview {
    @Previewable @State var text = ""
    return VStack(spacing: TIAGASpacing.lg) {
        ChatComposerBar(text: $text, isSendDisabled: text.isEmpty, onSend: {})
        ChatComposerBar(text: .constant(""), isSendDisabled: true, isStreaming: true, onSend: {}, onStop: {})
    }
    .padding()
    .background(TIAGAColor.background)
}
