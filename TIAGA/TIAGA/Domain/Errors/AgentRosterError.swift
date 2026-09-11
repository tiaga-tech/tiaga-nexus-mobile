//
//  AgentRosterError.swift
//  TIAGA
//

import Foundation

/// Failure states from `ListAgentRosterUseCase`. Encountered by the operator
/// opening the side menu.
enum AgentRosterError: Error, Equatable, LocalizedError {
    /// The backend couldn't be reached to list the fleet's agents.
    case fleetUnreachable

    var errorDescription: String? {
        switch self {
        case .fleetUnreachable:
            return "TIAGA couldn't reach your fleet. Check your connection and try again."
        }
    }
}
