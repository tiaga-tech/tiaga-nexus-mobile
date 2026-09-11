//
//  ChatView.swift
//  TIAGA
//

import SwiftUI

/// The main orchestrator chat screen: a text-only transcript that interleaves
/// messages and tool-usage events, the shared composer, a reset button, the
/// context-usage bar, and an entry point into the dynamic UI card history.
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showsDynamicUICardBrowser = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: TIAGASpacing.sm) {
                    if viewModel.transcript.isEmpty {
                        Text("Start a conversation with TIAGA.")
                            .font(TIAGATypography.subheadline)
                            .foregroundStyle(TIAGAColor.textTertiary)
                            .padding(.top, TIAGASpacing.xl)
                    } else {
                        ForEach(viewModel.transcript) { entry in
                            TranscriptRow(entry: entry)
                        }
                    }

                    if viewModel.isStreaming {
                        HStack(spacing: TIAGASpacing.xs) {
                            ProgressView()
                                .tint(TIAGAColor.brandAccent)
                            Text("TIAGA is replying…")
                                .font(TIAGATypography.caption)
                                .foregroundStyle(TIAGAColor.textTertiary)
                        }
                        .padding(.top, TIAGASpacing.sm)
                    }
                }
                .padding(TIAGASpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)

            if let message = viewModel.sendErrorMessage {
                Text(message)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.statusDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TIAGASpacing.lg)
                    .padding(.top, TIAGASpacing.sm)
            }

            if let message = viewModel.resetErrorMessage {
                Text(message)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.statusDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TIAGASpacing.lg)
                    .padding(.top, TIAGASpacing.sm)
            }

            ChatComposerBar(
                text: $viewModel.composerText,
                isSendDisabled: viewModel.composerText.isEmpty || viewModel.isStreaming,
                onSend: {
                    Task { await viewModel.send() }
                }
            )
            .padding(TIAGASpacing.lg)
        }
        .background(TIAGAColor.background)
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsDynamicUICardBrowser) {
            DynamicUICardBrowserView(viewModel: viewModel)
        }
    }

    private var header: some View {
        VStack(spacing: TIAGASpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
                    Text("Context window")
                        .font(TIAGATypography.caption)
                        .foregroundStyle(TIAGAColor.textSecondary)
                    ContextUsageBar(fraction: viewModel.contextUsage.fraction)
                        .frame(height: TIAGASpacing.xs)
                    Text(contextLabel)
                        .font(TIAGATypography.caption)
                        .foregroundStyle(contextColor)
                }

                Spacer()

                Button {
                    showsDynamicUICardBrowser = true
                } label: {
                    Image(systemName: TIAGAIcon.dynamicUIBrowser)
                        .foregroundStyle(TIAGAColor.textPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Browse dynamic UI cards")

                Button {
                    Task { await viewModel.reset() }
                } label: {
                    Image(systemName: TIAGAIcon.reset)
                        .foregroundStyle(TIAGAColor.textPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(viewModel.isStreaming)
                .accessibilityLabel("Reset conversation")
            }
        }
        .padding(.horizontal, TIAGASpacing.lg)
        .padding(.vertical, TIAGASpacing.md)
    }

    private var contextLabel: String {
        switch viewModel.contextUsage.level {
        case .normal:
            return "Normal"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }

    private var contextColor: Color {
        TIAGAColor.forContextUsage(percentage: viewModel.contextUsage.fraction)
    }
}

/// One chronological transcript row: a chat bubble for a message, or a dim
/// monospaced tool-usage line for an event.
private struct TranscriptRow: View {
    let entry: TranscriptEntry

    var body: some View {
        switch entry {
        case .message(let message):
            MessageBubble(
                kind: message.role == .operator ? .operatorMessage : .assistantMessage,
                text: message.text
            )
        case .toolUsage(let event):
            MessageBubble(kind: .toolUsage, text: event.summary)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
