//
//  RemoteAuthSessionRepository.swift
//  TIAGA
//

import Foundation

/// Talks to the real backend's `AuthController` (`/api/auth/*`) and
/// `RedeemController` (`/api/redeem`). See AGENTS.md's "Live backend"
/// policy — this is what every `AuthViewModel` outside Xcode Previews
/// actually runs against.
final class RemoteAuthSessionRepository: AuthSessionRepository {
    private let apiClient: TIAGAAPIClient
    private let cookieStore: SessionCookieStore
    private let eventBus: RemoteEventBus

    init(
        apiClient: TIAGAAPIClient = TIAGAAPIClient(),
        cookieStore: SessionCookieStore = SessionCookieStore(),
        eventBus: RemoteEventBus = .shared
    ) {
        self.apiClient = apiClient
        self.cookieStore = cookieStore
        self.eventBus = eventBus
    }

    func restoreSession() async throws -> Account? {
        // Cheap local check first — avoids a network round-trip on a fresh
        // install/logged-out device, per `SessionCookieStore`'s own doc comment.
        guard cookieStore.hasSessionCookie else { return nil }
        do {
            let payload: AccountPayload = try await apiClient.get("auth/me")
            return try payload.toAccount()
        } catch APITransportError.unauthorized {
            // Matches AuthController.Me's own doc comment: 401 here just
            // means logged out, not a failure to check.
            return nil
        }
    }

    func login(email: String, password: String) async throws -> Account {
        do {
            let payload: AccountPayload = try await apiClient.post(
                "auth/login",
                body: LoginRequestBody(email: email, password: password)
            )
            return try payload.toAccount()
        } catch APITransportError.unauthorized {
            throw LoginError.invalidCredentials
        } catch APITransportError.serverError(let status, _) where status == 429 {
            throw LoginError.tooManyAttempts
        } catch {
            throw LoginError.connectionUnavailable
        }
    }

    func redeemInviteCode(_ code: String) async throws -> Account {
        do {
            let _: RedeemResponseBody = try await apiClient.post(
                "redeem",
                body: RedeemRequestBody(code: code, tz: TimeZone.current.identifier)
            )
        } catch {
            // The backend's RedeemAsync has several distinct failure
            // messages (expired, already used, wrong tier, ...), all as a
            // generic 400 — this app's error surface only distinguishes
            // "invalid code" from "already active" (guarded client-side in
            // RedeemInviteCodeUseCase before this is ever called).
            throw InviteCodeError.codeInvalid
        }

        // Redeem's own response is just `{ ok, message }` — it doesn't
        // return the updated account, so re-fetch it to pick up the new
        // `.active` status.
        guard let account = try? await restoreSession() else {
            throw InviteCodeError.codeInvalid
        }
        return account
    }

    func logout() async throws {
        // The request must go out WITH the session cookie still attached so
        // the backend can look up and invalidate that exact session server-
        // side — clearing local storage first would send the logout request
        // with no cookie at all, leaving the session valid server-side for
        // its full 180-day sliding expiry. `defer` guarantees the local
        // clear still happens even if this call fails, matching
        // `FakeAuthSessionRepository`'s "local state clears unconditionally"
        // business rule. Disconnecting the shared event bus here too is
        // what lets logging into a *different* account (without an app
        // restart) actually receive that account's live updates — see
        // `RemoteEventBus.disconnect()`'s doc comment for why the
        // connection otherwise silently keeps running under the old
        // session's cookie.
        defer {
            cookieStore.clearSession()
            eventBus.disconnect()
        }
        try await apiClient.postExpectingNoContent("auth/logout")
    }
}

/// Shared response shape for `/api/auth/login` and `/api/auth/me`
/// (`AuthController.cs`'s `Login`/`Me` actions).
private struct AccountPayload: Decodable {
    let email: String
    let roles: [String]
    let status: String
    // An active subscription or extra credits (admins always true). The web
    // client force-routes an `.active`, non-admin account with this false to
    // a billing paywall on login — this app has no checkout flow to route
    // to (billing is deliberately read-only, web-only; see AGENTS.md), and
    // Settings' Usage/Billing sections already surface "no active plan"
    // gracefully, so this field is intentionally unused here rather than
    // gating Fleet Console access.
    let hasAccess: Bool?

    func toAccount() throws -> Account {
        guard let status = AccountStatus(rawValue: status) else {
            throw APITransportError.decodingFailed
        }
        // Unrecognized role strings (the backend's plain "user" default)
        // are silently dropped, not an error — `AccountRole` only models
        // capabilities this app actually branches on.
        let roles = Set(roles.compactMap(AccountRole.init(rawValue:)))
        return Account(email: email, status: status, roles: roles)
    }
}

private struct LoginRequestBody: Encodable {
    let email: String
    let password: String
}

private struct RedeemRequestBody: Encodable {
    let code: String
    let tz: String?
}

private struct RedeemResponseBody: Decodable {
    let ok: Bool
}
