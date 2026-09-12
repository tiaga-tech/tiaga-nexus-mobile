//
//  LoadAccountUsageUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

/// Thin purpose-built fake for `LoadAccountUsageUseCase` — fixed usage/plan
/// values and a failure switch.
private final class StubAccountRepository: AccountRepository {
    var shouldFail = false
    let usage: UsageSummary
    let plan: SubscriptionPlan

    init(
        usage: UsageSummary = .subscription(
            SubscriptionUsage(sessionPercentage: 10, sessionResetsAt: nil, weeklyPercentage: 20, weeklyResetsAt: nil, extraCreditsUsd: 0)
        ),
        plan: SubscriptionPlan = .active(ActivePlan(tierName: "Pro", endsAt: Date(), renewalStatus: .renewing))
    ) {
        self.usage = usage
        self.plan = plan
    }

    func loadUsageSummary() async throws -> UsageSummary {
        guard !shouldFail else { throw AccountUsageError.accountUnreachable }
        return usage
    }

    func loadSubscriptionPlan() async throws -> SubscriptionPlan {
        guard !shouldFail else { throw AccountUsageError.accountUnreachable }
        return plan
    }

    func loadPrivacyPreference() async throws -> PrivacyPreference {
        PrivacyPreference(improveAIEnabled: true)
    }

    func updatePrivacyPreference(_ preference: PrivacyPreference) async throws {}
}

struct LoadAccountUsageUseCaseTests {

    @Test func test_loadAccountUsage_succeeds_returningUsageAndPlan() async throws {
        let repository = StubAccountRepository()
        let useCase = LoadAccountUsageUseCase(repository: repository)

        let snapshot = try await useCase.execute()

        #expect(snapshot.usage == repository.usage)
        #expect(snapshot.plan == repository.plan)
    }

    @Test func test_loadAccountUsage_fails_whenAccountIsUnreachable() async throws {
        let repository = StubAccountRepository()
        repository.shouldFail = true
        let useCase = LoadAccountUsageUseCase(repository: repository)

        await #expect(throws: AccountUsageError.accountUnreachable) {
            try await useCase.execute()
        }
    }
}
