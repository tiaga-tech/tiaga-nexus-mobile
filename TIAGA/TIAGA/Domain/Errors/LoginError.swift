//
//  LoginError.swift
//  TIAGA
//

import Foundation

/// Failure states from `LoginUseCase`. Encountered by the operator on the
/// login screen — messages are written for them, not a developer.
enum LoginError: Error, Equatable, LocalizedError {
    /// The email/password pair (or its format) isn't valid. Covers both a
    /// malformed email and a genuinely wrong password — the login screen
    /// doesn't distinguish the two, to avoid confirming which part was wrong.
    case invalidCredentials
    /// The backend is rate-limiting this account after repeated attempts.
    case tooManyAttempts
    /// The request never reached the backend.
    case connectionUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "That email and password don't match a TIAGA account. Double-check them and try again."
        case .tooManyAttempts:
            return "Too many login attempts. Wait a few minutes, then try again."
        case .connectionUnavailable:
            return "TIAGA couldn't be reached. Check your connection and try again."
        }
    }
}
