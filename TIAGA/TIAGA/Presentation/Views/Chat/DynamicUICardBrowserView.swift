//
//  DynamicUICardBrowserView.swift
//  TIAGA
//

import SwiftUI

/// A simple history browser for the orchestrator's AI-composed dynamic UI
/// cards. The cards are re-rendered in the app's dark glass design system —
/// arbitrary web CSS from the backend is never trusted.
struct DynamicUICardBrowserView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TIAGASpacing.md) {
                    if let message = viewModel.dynamicCardHistoryErrorMessage {
                        Text(message)
                            .font(TIAGATypography.subheadline)
                            .foregroundStyle(TIAGAColor.statusDanger)
                            .frame(maxWidth: .infinity)
                            .padding(TIAGASpacing.lg)
                    } else if viewModel.dynamicCardHistory.isEmpty {
                        Text("No dynamic UI cards yet.")
                            .font(TIAGATypography.subheadline)
                            .foregroundStyle(TIAGAColor.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(TIAGASpacing.lg)
                    } else {
                        ForEach(viewModel.dynamicCardHistory) { card in
                            CardRow(
                                card: card,
                                onClose: { viewModel.dismissDynamicCard(id: card.id) }
                            )
                        }
                    }
                }
                .padding(TIAGASpacing.lg)
            }
            .background(TIAGAColor.background)
            .navigationTitle("Dynamic UI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: TIAGAIcon.close)
                            .foregroundStyle(TIAGAColor.textSecondary)
                    }
                }
            }
        }
        .task { await viewModel.loadDynamicCardHistory() }
    }
}

private struct CardRow: View {
    let card: DynamicUICard
    let onClose: () -> Void

    var body: some View {
        TIAGACard {
            VStack(alignment: .leading, spacing: TIAGASpacing.md) {
                HStack {
                    Text(card.title)
                        .font(TIAGATypography.headline)
                        .foregroundStyle(TIAGAColor.textPrimary)
                    Spacer(minLength: TIAGASpacing.sm)
                    Button(action: onClose) {
                        Image(systemName: TIAGAIcon.close)
                            .foregroundStyle(TIAGAColor.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Close card")
                }

                switch card.kind {
                case .text:
                    if let text = card.text {
                        Text(text)
                            .font(TIAGATypography.body)
                            .foregroundStyle(TIAGAColor.textPrimary)
                    }

                case .code:
                    if let language = card.language {
                        Text(language)
                            .font(TIAGATypography.caption)
                            .foregroundStyle(TIAGAColor.statusInfo)
                    }
                    if let code = card.code {
                        Text(code)
                            .font(TIAGATypography.command)
                            .foregroundStyle(TIAGAColor.textPrimary)
                            .textSelection(.enabled)
                    }

                case .table:
                    if let columns = card.columns {
                        TableView(columns: columns, rows: card.rows ?? [])
                    }

                case .error:
                    HStack(spacing: TIAGASpacing.xs) {
                        Image(systemName: TIAGAIcon.agentError)
                            .font(TIAGATypography.caption)
                        if let text = card.text {
                            Text(text)
                                .font(TIAGATypography.body)
                        }
                    }
                    .foregroundStyle(TIAGAColor.statusDanger)
                }
            }
        }
    }
}

private struct TableView: View {
    let columns: [String]
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
            HStack {
                ForEach(columns, id: \.self) { column in
                    Text(column)
                        .font(TIAGATypography.caption)
                        .foregroundStyle(TIAGAColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(TIAGATypography.caption)
                            .foregroundStyle(TIAGAColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

#Preview {
    DynamicUICardBrowserView(viewModel: ChatViewModel())
}

#Preview {
    CardRow(card: DynamicUICard(
        id: "ui-1",
        title: "Preview card",
        kind: .text,
        text: "Close this card.",
        code: nil,
        language: nil,
        columns: nil,
        rows: nil
    ), onClose: {})
    .padding()
    .background(TIAGAColor.background)
}
