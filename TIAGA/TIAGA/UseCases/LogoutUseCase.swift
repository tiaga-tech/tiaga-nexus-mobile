//
//  LogoutUseCase.swift
//  TIAGA
//

import Foundation

/// Ends the current session.
///
/// Business Rule: always clears the local session even if the remote
/// invalidation call fails — an operator must never be stuck "logged in"
/// locally because of a network error. There is no typed error: from the
/// operator's side, this cannot meaningfully fail.
///
/// (The UI trigger for this lives in Settings, Section 9 — defined here
/// because it's session logic, not settings logic.)
struct LogoutUseCase {
    let repository: AuthSessionRepository

    func execute() async {
        try? await repository.logout()
    }
}
