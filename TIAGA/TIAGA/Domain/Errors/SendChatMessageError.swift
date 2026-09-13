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
    /// The target is still streaming its previous reply — caught client-side
    /// before ever reaching the backend.
    case conversationBusy
    /// The backend rejected the message with its own specific reason: still
    /// thinking/compacting (a race with `conversationBusy`'s local check),
    /// a pending permission, or a billing gate (waitlisted, no active plan
    /// or credits). Carries the backend's own operator-facing message
    /// verbatim — matches the web client, which surfaces all of these
    /// identically regardless of which one it was (`BusyError` in `api.ts`).
    case rejectedByBackend(reason: String)

    var errorDescription: String? {
        switch self {
        case .messageIsEmpty:
            return "Type a message before sending."
        case .conversationBusy:
            return "TIAGA is still replying. Wait for the current response to finish, then try again."
        case .rejectedByBackend(let reason):
            return reason
        }
    }
}
