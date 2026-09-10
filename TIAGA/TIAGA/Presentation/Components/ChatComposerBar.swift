//
//  ChatComposerBar.swift
//  TIAGA
//

import SwiftUI

/// The shared text-input-and-send control for both the orchestrator Chat and
/// Agent Chat. Text only — no microphone button; voice is out of scope for
/// this app even though the desktop client is voice-first.
struct ChatComposerBar: View {
    @Binding var text: String
    let isSendDisabled: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: TIAGASpacing.sm) {
            TextField("Message", text: $text, axis: .vertical)
                .font(TIAGATypography.body)
                .foregroundStyle(TIAGAColor.textPrimary)
                .padding(.horizontal, TIAGASpacing.md)
                .padding(.vertical, TIAGASpacing.sm)
                .background(TIAGAColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous))

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(TIAGATypography.headline)
                    .imageScale(.large)
                    .foregroundStyle(isSendDisabled ? TIAGAColor.textTertiary : TIAGAColor.brandAccent)
            }
            .disabled(isSendDisabled)
        }
        .padding(TIAGASpacing.sm)
    }
}

#Preview {
    @Previewable @State var text = ""
    return ChatComposerBar(text: $text, isSendDisabled: text.isEmpty, onSend: {})
        .background(TIAGAColor.background)
}
