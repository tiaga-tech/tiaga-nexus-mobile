//
//  AuthViewModel.swift
//  TIAGA
//

import Combine
import Foundation

/// Drives the app's launch routing and the Login/Waitlist Gate screens.
@MainActor
final class AuthViewModel: ObservableObject {

    enum Route: Equatable {
        case checkingSession
        case login
        case waitlistGate(Account)
        case authenticated(Account)
    }

    @Published private(set) var route: Route = .checkingSession
    @Published var emailField: String = ""
    @Published var passwordField: String = ""
    @Published private(set) var loginErrorMessage: String?
    @Published var inviteCodeField: String = ""
    @Published private(set) var inviteCodeErrorMessage: String?
    @Published private(set) var isSubmitting = false

    private let repository: AuthSessionRepository
    private let restoreSessionUseCase: RestoreSessionUseCase
    private let loginUseCase: LoginUseCase
    private let redeemInviteCodeUseCase: RedeemInviteCodeUseCase
    private let logoutUseCase: LogoutUseCase

    init(repository: AuthSessionRepository? = nil) {
        // Fake*Repository only inside Xcode Previews — everywhere else
        // (Simulator or a real device) talks to the real backend. See
        // AGENTS.md's "Live backend" policy.
        let resolvedRepository = repository ?? (
            ProcessInfo.isRunningInXcodePreview ? FakeAuthSessionRepository() : RemoteAuthSessionRepository()
        )
        self.repository = resolvedRepository
        self.restoreSessionUseCase = RestoreSessionUseCase(repository: resolvedRepository)
        self.loginUseCase = LoginUseCase(repository: resolvedRepository)
        self.redeemInviteCodeUseCase = RedeemInviteCodeUseCase(repository: resolvedRepository)
        self.logoutUseCase = LogoutUseCase(repository: resolvedRepository)
    }

    func start() async {
        #if DEBUG
        // Screenshot/QA tooling only — lets `xcrun simctl launch` force a
        // specific screen (via SIMCTL_CHILD_TIAGA_DEBUG_ROUTE) without
        // driving real taps/typing. Never present in a Release build.
        if let overrideRoute = Self.debugRouteOverride() {
            route = overrideRoute
            return
        }
        #endif
        route = .checkingSession
        do {
            switch try await restoreSessionUseCase.execute() {
            case .unauthenticated:
                route = .login
            case .authenticated(let account):
                route = account.status == .waitlisted ? .waitlistGate(account) : .authenticated(account)
            }
        } catch {
            // No session to fall back to — the operator just logs in again.
            route = .login
        }
    }

    func submitLogin() async {
        loginErrorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let account = try await loginUseCase.execute(email: emailField, password: passwordField)
            route = account.status == .waitlisted ? .waitlistGate(account) : .authenticated(account)
        } catch let error as LoginError {
            loginErrorMessage = error.errorDescription
        } catch {
            loginErrorMessage = LoginError.connectionUnavailable.errorDescription
        }
    }

    func submitInviteCode() async {
        guard case .waitlistGate(let account) = route else { return }
        inviteCodeErrorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let activated = try await redeemInviteCodeUseCase.execute(code: inviteCodeField, for: account)
            route = .authenticated(activated)
        } catch let error as InviteCodeError {
            inviteCodeErrorMessage = error.errorDescription
        } catch {
            inviteCodeErrorMessage = "Something went wrong redeeming your code. Try again."
        }
    }

    func logout() async {
        await logoutUseCase.execute()
        emailField = ""
        passwordField = ""
        inviteCodeField = ""
        route = .login
    }

    #if DEBUG
    /// Fills the login fields with one of the fixture accounts, so both
    /// routing branches (active / waitlisted) are a tap away to exercise.
    func fillFixtureCredentials(active: Bool) {
        emailField = active ? FakeAuthSessionRepository.activeAccountEmail : FakeAuthSessionRepository.waitlistedAccountEmail
        passwordField = FakeAuthSessionRepository.fixturePassword
    }

    /// Reads `TIAGA_DEBUG_ROUTE` (pass via `SIMCTL_CHILD_TIAGA_DEBUG_ROUTE`
    /// to `xcrun simctl launch`) so a screenshot pass can force any screen
    /// — "login", "waitlistGate", "authenticated" — without real taps/typing.
    private static func debugRouteOverride() -> Route? {
        switch ProcessInfo.processInfo.environment["TIAGA_DEBUG_ROUTE"] {
        case "login":
            return .login
        case "waitlistGate":
            return .waitlistGate(Account(email: FakeAuthSessionRepository.waitlistedAccountEmail, status: .waitlisted, roles: []))
        case "authenticated":
            return .authenticated(Account(email: FakeAuthSessionRepository.activeAccountEmail, status: .active, roles: []))
        default:
            return nil
        }
    }
    #endif
}
