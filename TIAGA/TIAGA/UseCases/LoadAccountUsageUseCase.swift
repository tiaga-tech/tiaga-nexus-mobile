//
//  LoadAccountUsageUseCase.swift
//  TIAGA
//

import Foundation

/// `UsageSummary` and `SubscriptionPlan` together, since the real backend
/// resolves both from the same `/api/billing` call — the Settings screen
/// loads them as one unit, not two separately-timed requests.
struct AccountUsageSnapshot: Equatable, Sendable {
    let usage: UsageSummary
    let plan: SubscriptionPlan
}

/// Loads the signed-in operator's usage and billing plan, backing the
/// Settings screen's Usage and Billing sections.
struct LoadAccountUsageUseCase {
    let repository: AccountRepository

    func execute() async throws -> AccountUsageSnapshot {
        do {
            async let usage = repository.loadUsageSummary()
            async let plan = repository.loadSubscriptionPlan()
            return try await AccountUsageSnapshot(usage: usage, plan: plan)
        } catch {
            throw AccountUsageError.accountUnreachable
        }
    }
}
