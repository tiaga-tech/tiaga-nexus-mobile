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
struct ChatComposerBar: View {
    @Binding var text: String
    let isSendDisabled: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: TIAGASpacing.sm) {
            TextField("Message TIAGA…", text: $text, axis: .vertical)
                .font(TIAGATypography.body)
                .foregroundStyle(TIAGAColor.textPrimary)
                .padding(.horizontal, TIAGASpacing.sm)
                .padding(.vertical, TIAGASpacing.sm)

            Button("Send", action: onSend)
                .font(TIAGATypography.body)
                .foregroundStyle(TIAGAColor.textOnAccent)
                .padding(.horizontal, TIAGASpacing.md)
                .padding(.vertical, TIAGASpacing.sm)
                .background(TIAGAColor.brandAccent.opacity(isSendDisabled ? 0.3 : 0.8))
                .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.md, style: .continuous))
                .disabled(isSendDisabled)
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
    return ChatComposerBar(text: $text, isSendDisabled: text.isEmpty, onSend: {})
        .padding()
        .background(TIAGAColor.background)
}
