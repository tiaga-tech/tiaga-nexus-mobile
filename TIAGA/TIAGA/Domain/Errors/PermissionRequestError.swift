//
//  PermissionRequestError.swift
//  TIAGA
//

import Foundation

/// Failure states from `ReviewPermissionRequestUseCase`. Encountered by an
/// operator approving or denying a permission request.
enum PermissionRequestError: Error, Equatable, LocalizedError {
    /// The request was already approved or denied — nothing left to do.
    case requestAlreadyResolved

    var errorDescription: String? {
        switch self {
        case .requestAlreadyResolved:
            return "This request has already been resolved."
        }
    }
}
