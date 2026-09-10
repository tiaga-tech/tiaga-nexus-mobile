//
//  RedeemInviteCodeUseCase.swift
//  TIAGA
//

import Foundation

/// Redeems an invite code against the currently signed-in account, flipping
/// it from `.waitlisted` to `.active`.
///
/// Business Rule: only meaningful for a `.waitlisted` account — redeeming
/// against an already-`.active` account is rejected outright rather than
/// silently treated as a no-op, so the operator isn't left wondering whether
/// anything happened.
struct RedeemInviteCodeUseCase {
    let repository: AuthSessionRepository

    func execute(code: String, for account: Account) async throws -> Account {
        guard account.status == .waitlisted else {
            throw InviteCodeError.accountAlreadyActive
        }
        return try await repository.redeemInviteCode(code)
    }
}
