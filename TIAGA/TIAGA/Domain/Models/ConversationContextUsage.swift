//
//  ConversationContextUsage.swift
//  TIAGA
//

import Foundation

/// How full the orchestrator's context window is, and the urgency an operator
/// should attach to that number.
enum ConversationContextLevel: String, Equatable, Sendable {
    /// Comfortably under the compaction warning threshold.
    case normal
    /// At or above the warning threshold, but not yet full.
    case high
    /// At the hard limit — compaction is imminent or already happening.
    case critical
}

/// The orchestrator conversation's context-window usage.
///
/// Mirrors the backend's percentage-only `usage` event (raw token counts never
/// leave the server) and its `ContextWarnFraction = 0.75` threshold. The level
/// is derived, never stored: `.normal` below 75%, `.high` at 75% up to 100%,
/// `.critical` at 100%.
struct ConversationContextUsage: Equatable, Sendable {
    static let highThreshold: Double = 0.75
    static let criticalThreshold: Double = 1.0

    /// 0...1 — how full the context window is.
    let fraction: Double

    init(fraction: Double) {
        self.fraction = min(max(fraction, 0), 1)
    }

    var level: ConversationContextLevel {
        switch fraction {
        case ..<Self.highThreshold:
            return .normal
        case Self.highThreshold..<Self.criticalThreshold:
            return .high
        default:
            return .critical
        }
    }
}
