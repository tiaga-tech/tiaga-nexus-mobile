//
//  DynamicUICardBrowserView.swift
//  TIAGA
//

import SwiftUI
import UIKit

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

    @State private var showsExpanded = false
    @State private var copied = false

    private var canCopy: Bool {
        switch card.kind {
        case .text, .code: return true
        case .table, .diagram: return false
        }
    }

    var body: some View {
        TIAGACard {
            VStack(alignment: .leading, spacing: TIAGASpacing.md) {
                HStack(spacing: TIAGASpacing.sm) {
                    Text(card.title)
                        .font(TIAGATypography.headline)
                        .foregroundStyle(TIAGAColor.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: TIAGASpacing.sm)
                    Button {
                        showsExpanded = true
                    } label: {
                        Image(systemName: TIAGAIcon.expand)
                            .foregroundStyle(TIAGAColor.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Expand card")
                    Button(action: onClose) {
                        Image(systemName: TIAGAIcon.close)
                            .foregroundStyle(TIAGAColor.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Close card")
                }

                cardBody
            }
        }
        .sheet(isPresented: $showsExpanded) {
            ExpandedCardView(card: card, copied: $copied)
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        switch card.kind {
        case .text:
            if let text = card.text {
                Text(text)
                    .font(TIAGATypography.body)
                    .foregroundStyle(TIAGAColor.textPrimary)
            }

        case .code:
            CodeCardBody(card: card, copied: $copied)

        case .table:
            if let columns = card.columns {
                TableView(columns: columns, rows: card.rows ?? [])
            }

        case .diagram:
            if let diagram = card.diagram {
                MermaidDiagramView(source: diagram)
                    .frame(maxWidth: .infinity)
                    .background(TIAGAColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.sm, style: .continuous))
            }
        }
    }
}

/// A compact code block: language label + copy control above one flat
/// syntax-highlighted surface.
private struct CodeCardBody: View {
    let card: DynamicUICard
    @Binding var copied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
            HStack {
                Text((card.language ?? "code").uppercased())
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.textTertiary)
                Spacer()
                Button {
                    UIPasteboard.general.string = card.code
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        copied = false
                    }
                } label: {
                    Text(copied ? "Copied" : "Copy")
                        .font(TIAGATypography.caption)
                        .foregroundStyle(copied ? TIAGAColor.statusSuccess : TIAGAColor.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if let code = card.code {
                HighlightedCodeView(code: code, language: card.language ?? "plaintext")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.sm, style: .continuous))
            }
        }
    }
}

/// A fullscreen focus view for one dynamic UI card.
private struct ExpandedCardView: View {
    let card: DynamicUICard
    @Binding var copied: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: TIAGASpacing.md) {
                switch card.kind {
                case .text:
                    if let text = card.text {
                        ScrollView {
                            Text(text)
                                .font(TIAGATypography.body)
                                .foregroundStyle(TIAGAColor.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(TIAGASpacing.lg)
                        }
                    }

                case .code:
                    CodeCardBody(card: card, copied: $copied)
                        .padding(TIAGASpacing.lg)
                        .overlay {
                            if let code = card.code {
                                // The compact web view is non-scrolling; give the
                                // expanded code a scrollable web view instead.
                                HighlightedCodeView(code: code, language: card.language ?? "plaintext", isScrollable: true)
                                    .padding(.top, TIAGASpacing.xxl)
                            }
                        }

                case .table:
                    if let columns = card.columns {
                        TableView(columns: columns, rows: card.rows ?? [])
                            .padding(TIAGASpacing.lg)
                    }

                case .diagram:
                    if let diagram = card.diagram {
                        MermaidDiagramView(source: diagram, isInteractive: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(TIAGASpacing.lg)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(TIAGAColor.background)
            .navigationTitle(card.title)
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
    }
}

private struct TableView: View {
    let columns: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row — visually distinct from the body via a flat
                // elevated fill and secondary text.
                HStack(spacing: 0) {
                    ForEach(columns, id: \.self) { column in
                        Text(column)
                            .font(TIAGATypography.caption)
                            .foregroundStyle(TIAGAColor.textSecondary)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, TIAGASpacing.md)
                            .padding(.vertical, TIAGASpacing.sm)
                    }
                }
                .background(TIAGAColor.surfaceElevated)

                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(TIAGATypography.caption)
                                .foregroundStyle(TIAGAColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, TIAGASpacing.md)
                                .padding(.vertical, TIAGASpacing.sm)
                        }
                    }
                    if index < rows.count - 1 {
                        Divider()
                            .overlay(TIAGAColor.border)
                    }
                }
            }
            .background(TIAGAColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.sm, style: .continuous))
            .frame(minWidth: 0)
        }
    }
}

#Preview {
    DynamicUICardBrowserView(viewModel: ChatViewModel())
}
