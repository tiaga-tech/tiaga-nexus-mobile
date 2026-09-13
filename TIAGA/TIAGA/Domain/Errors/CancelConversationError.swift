//
//  CancelConversationError.swift
//  TIAGA
//

import Foundation

/// Failure states from `CancelConversationUseCase`. Encountered by an
/// operator tapping Stop while the orchestrator is replying.
enum CancelConversationError: Error, Equatable, LocalizedError {
    /// The cancel request couldn't reach the backend.
    case cancelFailed

    var errorDescription: String? {
        switch self {
        case .cancelFailed:
            return "Couldn't stop TIAGA right now. Check your connection and try again."
        }
    }
}
