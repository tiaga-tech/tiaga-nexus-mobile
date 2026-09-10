//
//  TIAGAColor.swift
//  TIAGA
//

import SwiftUI

/// Semantic color tokens for the TIAGA fleet console. Every color value used in
/// the app must come from this type — never construct `Color(...)` with raw
/// RGB/hex values in a View. Backing values live in Assets.xcassets/Colors and
/// carry light/dark variants, so token usage automatically adapts to appearance.
enum TIAGAColor {

    // MARK: Surfaces

    static let background = Color("Background")
    static let surface = Color("Surface")
    static let surfaceElevated = Color("SurfaceElevated")
    static let border = Color("Border")

    // MARK: Text

    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")

    // MARK: Brand

    static let brandAccent = Color("BrandAccent")

    // MARK: Status — generic semantic scale

    static let statusSuccess = Color("StatusSuccess")
    static let statusWarning = Color("StatusWarning")
    static let statusDanger = Color("StatusDanger")
    static let statusInfo = Color("StatusInfo")

    // MARK: Status — domain-specific

    /// An agent mid-compaction (context summarised into a self-handoff briefing).
    /// Mirrors the purple compacting indicator in the desktop client.
    static let statusCompacting = Color("StatusCompacting")

    /// A device or agent that is present but not actively doing anything.
    static let statusOffline = Color("StatusOffline")
}

// MARK: - Domain state → color mapping

extension TIAGAColor {

    /// Maps an `AgentState` to the color a fleet operator should see it as.
    static func forAgentState(_ state: AgentState) -> Color {
        switch state {
        case .idle: return statusOffline
        case .running: return statusInfo
        case .compacting: return statusCompacting
        case .error: return statusDanger
        }
    }

    /// Maps device online presence to a color.
    static func forDevicePresence(isOnline: Bool) -> Color {
        isOnline ? statusSuccess : statusOffline
    }

    /// Maps a permission request's urgency (time remaining before auto-deny)
    /// to a color, so the UI can warn an operator before a request expires unseen.
    static func forPermissionUrgency(_ urgency: PermissionRequestUrgency) -> Color {
        switch urgency {
        case .normal: return statusWarning
        case .expiringSoon: return statusDanger
        }
    }

    /// Maps a conversation's context-window usage (0...1) to a color, mirroring
    /// the real product's compaction thresholds: an agent is flagged at 75% and
    /// hits the hard limit at 100%, so the same boundaries drive the operator-
    /// facing context bar.
    static func forContextUsage(percentage: Double) -> Color {
        switch percentage {
        case ..<0.75: return statusSuccess
        case 0.75..<1.0: return statusWarning
        default: return statusDanger
        }
    }
}
