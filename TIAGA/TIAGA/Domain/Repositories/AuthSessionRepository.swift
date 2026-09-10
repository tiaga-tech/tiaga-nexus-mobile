//
//  AuthSessionRepository.swift
//  TIAGA
//

import Foundation

/// Where an authenticated session comes from. Protocol only — see
/// `Data/Repositories/FakeAuthSessionRepository.swift` for the (fixture-
/// backed, no-network) implementation. Never call this directly from a
/// View; go through a Use Case.
protocol AuthSessionRepository {
    /// Returns the currently signed-in account, or `nil` if there is none.
    /// Throws only on an actual failure to check — no session is not a failure.
    func restoreSession() async throws -> Account?

    /// Throws `LoginError` on failure.
    func login(email: String, password: String) async throws -> Account

    /// Redeems an invite code against the currently signed-in account.
    /// Throws `InviteCodeError` on failure.
    func redeemInviteCode(_ code: String) async throws -> Account

    /// Ends the session. May throw if a remote invalidation fails — callers
    /// (`LogoutUseCase`) must still treat the local session as cleared
    /// regardless, per that Use Case's business rule.
    func logout() async throws
}
