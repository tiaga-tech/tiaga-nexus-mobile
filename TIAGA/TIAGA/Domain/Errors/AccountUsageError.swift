//
//  AccountUsageError.swift
//  TIAGA
//

import Foundation

/// Failure states from `LoadAccountUsageUseCase`. Encountered by an
/// operator opening the Settings screen's Usage/Billing sections.
enum AccountUsageError: Error, Equatable, LocalizedError {
    /// The account/billing service couldn't be reached.
    case accountUnreachable

    var errorDescription: String? {
        switch self {
        case .accountUnreachable:
            return "Couldn't load your usage and plan right now. Check your connection and try again."
        }
    }
}
