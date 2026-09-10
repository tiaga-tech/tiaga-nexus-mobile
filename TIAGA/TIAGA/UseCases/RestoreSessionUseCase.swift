//
//  RestoreSessionUseCase.swift
//  TIAGA
//

import Foundation

/// The result of checking for an existing session on launch. `.unauthenticated`
/// is a normal outcome, not a failure — most launches with no prior session
/// look like this.
enum SessionRestoreOutcome: Equatable {
    case unauthenticated
    case authenticated(Account)
}

/// Checks for a valid existing session on launch, so a returning `.active`
/// user skips straight past Login, and a returning `.waitlisted` user skips
/// straight to the waitlist gate instead of re-entering credentials.
struct RestoreSessionUseCase {
    let repository: AuthSessionRepository

    func execute() async throws -> SessionRestoreOutcome {
        do {
            guard let account = try await repository.restoreSession() else {
                return .unauthenticated
            }
            return .authenticated(account)
        } catch {
            throw SessionRestoreError.connectionUnavailable
        }
    }
}
