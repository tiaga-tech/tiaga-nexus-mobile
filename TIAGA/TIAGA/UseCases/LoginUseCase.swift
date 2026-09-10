//
//  LoginUseCase.swift
//  TIAGA
//

import Foundation

/// Signs an operator into TIAGA with an email and password.
///
/// Business Rule: the email must look like an email and the password must
/// not be empty before this even reaches the backend — a malformed
/// submission fails the same way a wrong password does (`.invalidCredentials`),
/// so the error surface stays simple for the operator.
struct LoginUseCase {
    let repository: AuthSessionRepository

    func execute(email: String, password: String) async throws -> Account {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.looksLikeEmail(trimmedEmail), !password.isEmpty else {
            throw LoginError.invalidCredentials
        }
        return try await repository.login(email: trimmedEmail, password: password)
    }

    private static func looksLikeEmail(_ candidate: String) -> Bool {
        let parts = candidate.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        return parts[1].contains(".") && !parts[1].hasPrefix(".") && !parts[1].hasSuffix(".")
    }
}
