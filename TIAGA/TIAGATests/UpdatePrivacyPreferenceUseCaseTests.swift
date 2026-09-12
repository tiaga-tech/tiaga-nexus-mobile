//
//  UpdatePrivacyPreferenceUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

/// Thin purpose-built fake for `UpdatePrivacyPreferenceUseCase` — records
/// the last preference written and can simulate an offline failure.
private final class StubAccountRepository: AccountRepository {
    var shouldFail = false
    private(set) var lastUpdatedPreference: PrivacyPreference?

    func loadUsageSummary() async throws -> UsageSummary { .noActivePlan(extraCreditsUsd: 0) }
    func loadSubscriptionPlan() async throws -> SubscriptionPlan { .none }
    func loadPrivacyPreference() async throws -> PrivacyPreference { PrivacyPreference(improveAIEnabled: true) }

    func updatePrivacyPreference(_ preference: PrivacyPreference) async throws {
        guard !shouldFail else { throw PrivacyPreferenceError.updateFailedWhileOffline }
        lastUpdatedPreference = preference
    }
}

struct UpdatePrivacyPreferenceUseCaseTests {

    @Test func test_updatePrivacyPreference_succeeds_whenOnline() async throws {
        let repository = StubAccountRepository()
        let useCase = UpdatePrivacyPreferenceUseCase(repository: repository)

        try await useCase.execute(PrivacyPreference(improveAIEnabled: false))

        #expect(repository.lastUpdatedPreference == PrivacyPreference(improveAIEnabled: false))
    }

    @Test func test_updatePrivacyPreference_fails_whenOffline() async throws {
        let repository = StubAccountRepository()
        repository.shouldFail = true
        let useCase = UpdatePrivacyPreferenceUseCase(repository: repository)

        await #expect(throws: PrivacyPreferenceError.updateFailedWhileOffline) {
            try await useCase.execute(PrivacyPreference(improveAIEnabled: false))
        }
    }
}
