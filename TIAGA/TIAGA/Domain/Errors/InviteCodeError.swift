//
//  InviteCodeError.swift
//  TIAGA
//

import Foundation

/// Failure states from `RedeemInviteCodeUseCase`. Encountered by a
/// `.waitlisted` operator on the waitlist gate screen.
enum InviteCodeError: Error, Equatable, LocalizedError {
    /// The code doesn't match any invite the backend issued.
    case codeInvalid
    /// The account is already `.active` — there is nothing to redeem.
    case accountAlreadyActive

    var errorDescription: String? {
        switch self {
        case .codeInvalid:
            return "That invite code isn't valid. Double-check it against the one TIAGA sent you."
        case .accountAlreadyActive:
            return "Your account already has access — there's nothing to redeem."
        }
    }
}
