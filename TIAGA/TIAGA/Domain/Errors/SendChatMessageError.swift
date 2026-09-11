//
//  SendChatMessageError.swift
//  TIAGA
//

import Foundation

/// Failure states from `SendChatMessageUseCase`. Encountered by an operator
/// trying to message the orchestrator (or, later, an agent).
enum SendChatMessageError: Error, Equatable, LocalizedError {
    /// The submitted text was empty or whitespace-only.
    case messageIsEmpty
    /// The target is still streaming its previous reply.
    case conversationBusy

    var errorDescription: String? {
        switch self {
        case .messageIsEmpty:
            return "Type a message before sending."
        case .conversationBusy:
            return "TIAGA is still replying. Wait for the current response to finish, then try again."
        }
    }
}
