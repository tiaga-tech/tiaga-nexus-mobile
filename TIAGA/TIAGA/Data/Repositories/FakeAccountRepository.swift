//
//  FakeAccountRepository.swift
//  TIAGA
//

import Foundation

/// Fixture-backed `AccountRepository` — plain Swift values held in memory,
/// no network calls. See AGENTS.md's "Live backend" policy.
final class FakeAccountRepository: AccountRepository, @unchecked Sendable {

    /// Which of `UsageSummary`'s three real, mutually exclusive states this
    /// fixture simulates — see `SIMCTL_CHILD_TIAGA_DEBUG_USAGE_VARIANT` in
    /// `SettingsViewModel` for how a screenshot pass picks one.
    enum UsageVariant {
        /// The common case: a subscribed, non-admin account.
        case subscription
        /// An admin account — no plan limits, sees real dollar cost.
        case admin
        /// A regular account that hasn't subscribed (may still have a
        /// leftover extra-credits balance).
        case noActivePlan
    }

    private let lock = NSLock()
    private let usageVariant: UsageVariant
    /// Thrown by every call when set — simulates the account/billing
    /// service being unreachable, matching `AccountUsageError.accountUnreachable`.
    private let simulatedFailure: Error?
    private var privacyPreference: PrivacyPreference

    init(usageVariant: UsageVariant = .subscription, simulatedFailure: Error? = nil) {
        self.usageVariant = usageVariant
        self.simulatedFailure = simulatedFailure
        self.privacyPreference = PrivacyPreference(improveAIEnabled: true)
    }

    func loadUsageSummary() async throws -> UsageSummary {
        if let simulatedFailure { throw simulatedFailure }
        switch usageVariant {
        case .subscription:
            return .subscription(
                SubscriptionUsage(
                    sessionPercentage: 42,
                    sessionResetsAt: Date().addingTimeInterval(2 * 60 * 60),
                    weeklyPercentage: 68,
                    weeklyResetsAt: Date().addingTimeInterval(4 * 24 * 60 * 60),
                    extraCreditsUsd: 3.50
                )
            )
        case .admin:
            return .admin(
                AdminUsage(sessionUsd: 1.24, weeklyUsd: 18.42, last30DaysUsd: 76.90, allTimeUsd: 412.15)
            )
        case .noActivePlan:
            return .noActivePlan(extraCreditsUsd: 2.00)
        }
    }

    func loadSubscriptionPlan() async throws -> SubscriptionPlan {
        if let simulatedFailure { throw simulatedFailure }
        switch usageVariant {
        case .subscription:
            return .active(
                ActivePlan(
                    tierName: "Pro",
                    endsAt: Date().addingTimeInterval(18 * 24 * 60 * 60),
                    renewalStatus: .renewing
                )
            )
        case .admin, .noActivePlan:
            // Real accounts can be admin AND subscribed, or plan-less and
            // not admin — this fixture only needs one clean example of
            // each `UsageSummary` case, not every cross-product, so both
            // non-subscription variants simply have no plan on file.
            return .none
        }
    }

    func loadPrivacyPreference() async throws -> PrivacyPreference {
        if let simulatedFailure { throw simulatedFailure }
        return lock.withLock { privacyPreference }
    }

    func updatePrivacyPreference(_ preference: PrivacyPreference) async throws {
        if let simulatedFailure { throw simulatedFailure }
        lock.withLock { privacyPreference = preference }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
