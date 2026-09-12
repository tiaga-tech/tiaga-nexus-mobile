//
//  DynamicUICardHistoryError.swift
//  TIAGA
//

import Foundation

/// Failure states from `LoadDynamicUICardHistoryUseCase`. Encountered by an
/// operator browsing the orchestrator's previously displayed cards.
enum DynamicUICardHistoryError: Error, Equatable, LocalizedError {
    /// The card history could not be loaded.
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "TIAGA couldn't load the dynamic UI cards right now. Try again in a moment."
        }
    }
}
