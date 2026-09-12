//
//  TIAGAColor.swift
//  TIAGA
//

import SwiftUI

/// Semantic color tokens for the TIAGA fleet console. Every color value used in
/// the app must come from this type — never construct `Color(...)` with raw
/// RGB/hex values in a View. Backing values live in Assets.xcassets/Colors.
///
/// The app is dark-only, matching the real TIAGA product's actual visual
/// identity (a near-black canvas with translucent "glass" surfaces) rather
/// than an invented light theme — see `TIAGAApp.swift`'s forced dark scheme.
enum TIAGAColor {

    // MARK: Surfaces

    /// The app canvas — near-black, matching the real product's `#05070d`.
    static let background = Color("Background")
    /// Flat translucent fill for small chips/badges (not blurred — see `TIAGACard`
    /// for actual glass panels, which use a real Material blur instead).
    static let surface = Color("Surface")
    /// A slightly more opaque translucent fill, for hover/elevated states.
    static let surfaceElevated = Color("SurfaceElevated")
    static let border = Color("Border")

    // MARK: Text

    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")
    /// Text drawn on top of a filled `brandAccent` surface (e.g. the Send button).
    static let textOnAccent = Color.white

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

    /// A muted, non-alarming state — an idle agent, "nothing to report".
    /// Distinct from `statusDanger`: idle is normal, offline/error are not.
    static let statusNeutral = Color("StatusNeutral")
}

// MARK: - Domain state → color mapping

extension TIAGAColor {

    /// Maps an `AgentState` to the color a fleet operator should see it as.
    static func forAgentState(_ state: AgentState) -> Color {
        switch state {
        case .idle: return statusNeutral
        case .running: return brandAccent
        case .compacting: return statusCompacting
        case .error: return statusDanger
        }
    }

    /// Maps device online presence to a color. An offline device is a problem,
    /// not a neutral state — it uses `statusDanger`, matching the real product's
    /// own device list (red, not gray, for offline).
    static func forDevicePresence(isOnline: Bool) -> Color {
        isOnline ? statusSuccess : statusDanger
    }

    /// Maps a permission request's urgency (time remaining before auto-deny)
    /// to a color, so the UI can warn an operator before a request expires unseen.
    static func forPermissionUrgency(_ urgency: PermissionRequestUrgency) -> Color {
        switch urgency {
        case .normal: return statusWarning
        case .expiringSoon: return statusDanger
        }
    }

    /// Maps a `ChatMessageKind` to the label/dot color a transcript row shows
    /// above it, matching the real web client's `KIND_STYLES`
    /// (`MessageList.tsx`) hue-for-hue: voice→blue, tool→amber,
    /// context→neutral gray, task→success green, ui→violet (reusing the
    /// compacting purple — a distinct violet token isn't otherwise needed),
    /// error→danger red.
    static func forChatMessageKind(_ kind: ChatMessageKind) -> Color {
        switch kind {
        case .voice: return brandAccent
        case .tool: return statusWarning
        case .context: return statusNeutral
        case .task: return statusSuccess
        case .ui: return statusCompacting
        case .error: return statusDanger
        }
    }

    /// Maps a conversation's context-window usage (0...1) to a color, mirroring
    /// the web client's `ContextBar`: green below 60%, amber at 60% up to 85%,
    /// red at 85% and above. (Distinct from account/billing usage, which uses
    /// its own metering scale — see TODO.md Section 9.)
    static func forContextUsage(percentage: Double) -> Color {
        switch percentage {
        case ..<0.60: return statusSuccess
        case 0.60..<0.85: return statusWarning
        default: return statusDanger
        }
    }
}
