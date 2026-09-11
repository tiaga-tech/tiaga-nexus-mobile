//
//  DynamicUICard.swift
//  TIAGA
//

import Foundation

/// The kind of AI-composed card the orchestrator put on screen.
///
/// Matches the real `DynamicUiManager` tools: `add_dynamic_ui` produces
/// `.text`, `add_code_ui` produces `.code`, `add_table_ui` produces `.table`,
/// and a user-visible error line (e.g. the usage-stop message) renders as
/// `.error`. Diagram cards are intentionally not modeled here — Section 5 is
/// text-only and the mobile browser does not render Mermaid.
enum DynamicUICardKind: String, Equatable, CaseIterable, Sendable {
    case text
    case code
    case table
    case error
}

/// One AI-composed visual card from the orchestrator.
///
/// Represents the real backend's `DynamicCard` (`DynamicUiManager.cs`),
/// flattened into the fields a mobile history browser can render: title plus
/// the payload relevant to its kind. Width/height/colour styling from the web
/// card is deliberately omitted — this browser re-renders each card in the
/// app's own dark glass design system instead of trusting arbitrary web CSS.
struct DynamicUICard: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let kind: DynamicUICardKind
    let text: String?
    let code: String?
    let language: String?
    let columns: [String]?
    let rows: [[String]]?
}
