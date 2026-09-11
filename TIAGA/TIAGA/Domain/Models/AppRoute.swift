//
//  AppRoute.swift
//  TIAGA
//

import Foundation

/// A destination in the fleet console's navigation shell, selected from the
/// side menu.
enum AppRoute: Equatable, Hashable {
    case chat
    case agentChat(AgentIdentifier)
    case devices
    case settings
}
