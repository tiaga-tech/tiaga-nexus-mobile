//
//  UpdatePrivacyPreferenceUseCase.swift
//  TIAGA
//

import Foundation

/// Persists a change to the operator's privacy preference, backing the
/// Settings screen's privacy switch.
///
/// Business rule: this only ever changes what's collected *going forward*
/// — it must never trigger, or imply, retroactive deletion of conversations
/// already used for training. There is no delete-my-data action here by
/// design; that's a deliberate omission, not a gap to fill in later.
struct UpdatePrivacyPreferenceUseCase {
    let repository: AccountRepository

    func execute(_ preference: PrivacyPreference) async throws {
        do {
            try await repository.updatePrivacyPreference(preference)
        } catch {
            throw PrivacyPreferenceError.updateFailedWhileOffline
        }
    }
}
