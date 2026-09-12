//
//  ResetConversationError.swift
//  TIAGA
//

import Foundation

/// Failure states from `ResetConversationUseCase`. Encountered by an operator
/// resetting the orchestrator conversation.
enum ResetConversationError: Error, Equatable, LocalizedError {
    /// A response is actively streaming; resetting now would discard it
    /// mid-flight.
    case conversationBusy

    var errorDescription: String? {
        switch self {
        case .conversationBusy:
            return "TIAGA is still replying. Wait for the current response to finish before resetting."
        }
    }
}
