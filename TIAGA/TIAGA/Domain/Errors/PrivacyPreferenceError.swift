//
//  PrivacyPreferenceError.swift
//  TIAGA
//

import Foundation

/// Failure states from `UpdatePrivacyPreferenceUseCase`. Encountered by an
/// operator toggling the Settings screen's privacy switch.
enum PrivacyPreferenceError: Error, Equatable, LocalizedError {
    /// The change couldn't reach the backend to persist — the switch should
    /// revert to its last known value rather than claim success.
    case updateFailedWhileOffline

    var errorDescription: String? {
        switch self {
        case .updateFailedWhileOffline:
            return "Couldn't save that change. Check your connection and try again."
        }
    }
}
