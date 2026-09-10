//
//  FakeAuthSessionRepository.swift
//  TIAGA
//

import Foundation

/// Fixture-backed `AuthSessionRepository` — plain Swift values held in
/// memory, no network calls, ever. See CLAUDE.md's "Testing safety: no live
/// backend" policy. Used by both the running app (so it's actually possible
/// to explore Login/Waitlist Gate in the simulator) and Use Case tests.
final class FakeAuthSessionRepository: AuthSessionRepository {

    /// A fixture account that's already past the waitlist.
    static let activeAccountEmail = "active@tiaga.tech"
    /// A fixture account still waiting for an invite.
    static let waitlistedAccountEmail = "waitlisted@tiaga.tech"
    /// The one password every fixture account accepts.
    static let fixturePassword = "correct-password"
    /// Any login attempt with this email simulates a rate-limited backend.
    static let rateLimitedEmail = "ratelimited@tiaga.tech"
    /// The one code `redeemInviteCode` accepts.
    static let validInviteCode = "WELCOME-TO-TIAGA"

    /// Set on `logout()` to make its (fake) remote call fail — the local
    /// session must still clear regardless. Exists purely so
    /// `LogoutUseCase` can be tested against that resilience rule.
    var shouldFailRemoteLogout = false

    /// Set to simulate a connectivity failure on the next `restoreSession()` call.
    var shouldFailRestoreSession = false

    private var currentSession: Account?

    func restoreSession() async throws -> Account? {
        if shouldFailRestoreSession {
            throw SimulatedTransportFailure()
        }
        return currentSession
    }

    func login(email: String, password: String) async throws -> Account {
        if email == Self.rateLimitedEmail {
            throw LoginError.tooManyAttempts
        }

        let account: Account
        switch email {
        case Self.activeAccountEmail:
            account = Account(email: email, status: .active, roles: [])
        case Self.waitlistedAccountEmail:
            account = Account(email: email, status: .waitlisted, roles: [])
        default:
            throw LoginError.invalidCredentials
        }

        guard password == Self.fixturePassword else {
            throw LoginError.invalidCredentials
        }

        currentSession = account
        return account
    }

    func redeemInviteCode(_ code: String) async throws -> Account {
        guard code == Self.validInviteCode else {
            throw InviteCodeError.codeInvalid
        }
        guard let waitlisted = currentSession, waitlisted.status == .waitlisted else {
            // The Use Case already guards this; keep the fake internally
            // consistent if it's ever called directly.
            throw InviteCodeError.accountAlreadyActive
        }

        let activated = Account(email: waitlisted.email, status: .active, roles: waitlisted.roles)
        currentSession = activated
        return activated
    }

    func logout() async throws {
        // Local state clears first, unconditionally — the (fake) "remote"
        // failure below never gets a chance to leave it stale.
        currentSession = nil
        if shouldFailRemoteLogout {
            throw SimulatedTransportFailure()
        }
    }
}

/// A stand-in for "the real remote invalidation call failed" — the specific
/// error type doesn't matter, since `LogoutUseCase` discards it unconditionally.
private struct SimulatedTransportFailure: Error {}
