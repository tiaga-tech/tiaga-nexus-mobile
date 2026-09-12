//
//  AccountRepository.swift
//  TIAGA
//

import Foundation

/// Source of the signed-in operator's usage, billing plan, and privacy
/// preference — the real backend serves usage and plan from the same
/// `/api/billing` response (mirrored here as two calls on one protocol,
/// not two repositories, since they're one domain noun: `Account`).
protocol AccountRepository: Sendable {
    func loadUsageSummary() async throws -> UsageSummary
    func loadSubscriptionPlan() async throws -> SubscriptionPlan
    func loadPrivacyPreference() async throws -> PrivacyPreference
    func updatePrivacyPreference(_ preference: PrivacyPreference) async throws
}
