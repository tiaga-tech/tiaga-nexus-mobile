//
//  SessionRestoreError.swift
//  TIAGA
//

import Foundation

/// Failure states from `RestoreSessionUseCase`. Note that "no session
/// exists" is a normal outcome (`SessionRestoreOutcome.unauthenticated`),
/// not an error — this type only covers actual failures to check.
enum SessionRestoreError: Error, Equatable, LocalizedError {
    /// The backend couldn't be reached to check for an existing session.
    case connectionUnavailable

    var errorDescription: String? {
        switch self {
        case .connectionUnavailable:
            return "TIAGA couldn't be reached to check your session. Check your connection and try again."
        }
    }
}
