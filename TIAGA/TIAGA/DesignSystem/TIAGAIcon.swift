//
//  TIAGAIcon.swift
//  TIAGA
//

import Foundation

/// SF Symbol name tokens. Every `Image(systemName:)` must use one of these —
/// never an inline symbol-name string literal in a View, so an icon only
/// changes in one place.
enum TIAGAIcon {

    // MARK: Device types

    static let deviceMacOS = "laptopcomputer"
    static let deviceWindows = "pc"
    static let deviceLinux = "terminal"

    // MARK: Agent state

    static let agentIdle = "moon.zzz.fill"
    static let agentRunning = "bolt.fill"
    static let agentCompacting = "arrow.triangle.2.circlepath"
    static let agentError = "exclamationmark.triangle.fill"

    // MARK: Tool-usage kinds (mirrors the harness's actual tool set)

    static let toolBash = "terminal.fill"
    static let toolEdit = "pencil"
    static let toolWrite = "square.and.pencil"
    static let toolRunApp = "app.badge.fill"
    static let toolKillProcess = "xmark.octagon.fill"

    // MARK: Side menu entries

    static let menuChat = "bubble.left.and.bubble.right.fill"
    static let menuDevices = "server.rack"
    static let menuSettings = "gearshape.fill"
}

// MARK: - Domain state → icon mapping

extension TIAGAIcon {
    /// Maps an `AgentState` to the symbol a fleet operator should see it as.
    static func forAgentState(_ state: AgentState) -> String {
        switch state {
        case .idle: return agentIdle
        case .running: return agentRunning
        case .compacting: return agentCompacting
        case .error: return agentError
        }
    }
}
