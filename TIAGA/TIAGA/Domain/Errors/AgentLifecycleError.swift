//
//  AgentLifecycleError.swift
//  TIAGA
//

import Foundation

/// Failure states from `CancelAgentTaskUseCase` and `DeleteAgentUseCase`.
/// Encountered by an operator managing an agent from Agent Chat.
enum AgentLifecycleError: Error, Equatable, LocalizedError {
    /// The agent is `.idle` or `.error`, so there is no active task to
    /// cancel.
    case noActiveTaskToCancel
    /// The agent is `.compacting` — per `AgentState.compacting`'s own
    /// business rule, this is a self-contained transition that must finish
    /// on its own, not a task the operator can interrupt.
    case cannotInterruptCompaction
    /// The agent no longer exists — it may have already been deleted, or
    /// (for a send) removed between opening the screen and sending.
    case agentNoLongerExists

    var errorDescription: String? {
        switch self {
        case .noActiveTaskToCancel:
            return "This agent isn't running a task right now, so there's nothing to cancel."
        case .cannotInterruptCompaction:
            return "This agent is compacting its history and can't be interrupted. Wait for it to finish."
        case .agentNoLongerExists:
            return "This agent no longer exists — it may have already been deleted."
        }
    }
}
