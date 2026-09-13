//
//  RemoteAccountRepository.swift
//  TIAGA
//

import Foundation

/// Talks to the real backend's `BillingController` (`GET /api/billing`) and
/// `ChatController`'s privacy endpoints (`GET`/`POST /api/privacy` — there is
/// no dedicated privacy controller; checked directly, it lives alongside
/// chat). See AGENTS.md's "Live backend" policy — this is what
/// `SettingsViewModel` runs against outside Xcode Previews.
///
/// **Simplification**: `loadUsageSummary()` and `loadSubscriptionPlan()` each
/// independently call `GET /api/billing`, even though the real backend
/// resolves both from the one response (see this protocol's own doc
/// comment) — `LoadAccountUsageUseCase` fires them concurrently via
/// `async let`, so this costs one extra small JSON round-trip per Settings
/// visit rather than a shared in-flight fetch. Not worth the extra
/// machinery for a screen loaded once per visit; revisit if Settings ever
/// needs a live-updating usage bar.
final class RemoteAccountRepository: AccountRepository {
    private let apiClient: TIAGAAPIClient

    init(apiClient: TIAGAAPIClient = TIAGAAPIClient()) {
        self.apiClient = apiClient
    }

    func loadUsageSummary() async throws -> UsageSummary {
        do {
            let payload: BillingInfoPayload = try await apiClient.get("billing")
            return payload.toUsageSummary()
        } catch {
            throw AccountUsageError.accountUnreachable
        }
    }

    func loadSubscriptionPlan() async throws -> SubscriptionPlan {
        do {
            let payload: BillingInfoPayload = try await apiClient.get("billing")
            return try payload.toSubscriptionPlan()
        } catch {
            throw AccountUsageError.accountUnreachable
        }
    }

    func loadPrivacyPreference() async throws -> PrivacyPreference {
        // No dedicated error case: the caller (`SettingsViewModel.load()`)
        // treats any failure identically (the switch just stays disabled),
        // so there's nothing gained by inventing one nobody observes.
        let payload: PrivacyPayload = try await apiClient.get("privacy")
        return PrivacyPreference(improveAIEnabled: !payload.trainingOptOut)
    }

    func updatePrivacyPreference(_ preference: PrivacyPreference) async throws {
        do {
            let _: PrivacyPayload = try await apiClient.post(
                "privacy",
                body: PrivacyUpdateBody(trainingOptOut: !preference.improveAIEnabled)
            )
        } catch {
            throw PrivacyPreferenceError.updateFailedWhileOffline
        }
    }
}

// MARK: - Wire payloads

/// `GET /api/billing`'s shape (`BillingController.Info`). `role`/`status`
/// exist on the wire but aren't needed here — this app already has the
/// signed-in account's status/roles from `/api/auth/me`
/// (`RemoteAuthSessionRepository`). Verified directly against the real
/// backend: `role` there is a single comma-joined string
/// ("admin,developer"), not an array — one more reason not to duplicate it
/// here from a second source.
private struct BillingInfoPayload: Decodable {
    let subscription: SubscriptionPayload?
    let upcoming: [UpcomingPeriodPayload]
    let pendingSwitch: PendingSwitchPayload?
    let sessionPct: Double?
    let weeklyPct: Double?
    let sessionResetsAt: String?
    let weeklyResetsAt: String?
    let extraCreditsUsd: Double
    let adminUsage: AdminUsagePayload?

    /// Matches `UsagePanel.tsx`'s exact precedence: `adminUsage` present
    /// wins regardless of `subscription`, then `subscription` present,
    /// else no active plan.
    func toUsageSummary() -> UsageSummary {
        if let adminUsage {
            return .admin(AdminUsage(
                sessionUsd: adminUsage.sessionUsd,
                weeklyUsd: adminUsage.weeklyUsd,
                last30DaysUsd: adminUsage.last30DaysUsd,
                allTimeUsd: adminUsage.allTimeUsd
            ))
        }
        if subscription != nil {
            return .subscription(SubscriptionUsage(
                sessionPercentage: sessionPct ?? 0,
                sessionResetsAt: sessionResetsAt.flatMap(WireDate.parse),
                weeklyPercentage: weeklyPct ?? 0,
                weeklyResetsAt: weeklyResetsAt.flatMap(WireDate.parse),
                extraCreditsUsd: extraCreditsUsd
            ))
        }
        return .noActivePlan(extraCreditsUsd: extraCreditsUsd)
    }

    /// Matches `BillingPanel.tsx`'s exact precedence: a scheduled switch
    /// beats queued time, which beats auto-renew — each one moot once
    /// something higher in the list is already true. Checked directly:
    /// "renewing" requires `stripeBilled && autoRenew` together, not
    /// `autoRenew` alone (a non-Stripe-billed plan can have `autoRenew`
    /// true on the wire but nothing actually billing it forward).
    func toSubscriptionPlan() throws -> SubscriptionPlan {
        guard let subscription else { return .none }
        guard let endsAt = WireDate.parse(subscription.endsAt) else {
            throw APITransportError.decodingFailed
        }

        let renewalStatus: ActivePlan.RenewalStatus
        if let pendingSwitch {
            renewalStatus = .switchingTo(tierName: pendingSwitch.tierName)
        } else if !upcoming.isEmpty {
            renewalStatus = .queued
        } else if subscription.stripeBilled && subscription.autoRenew {
            renewalStatus = .renewing
        } else {
            renewalStatus = .ending
        }

        return .active(ActivePlan(tierName: subscription.tierName, endsAt: endsAt, renewalStatus: renewalStatus))
    }
}

private struct SubscriptionPayload: Decodable {
    let tierName: String
    let endsAt: String
    let autoRenew: Bool
    let stripeBilled: Bool
}

/// Only `tierName` is needed — this app only checks *whether* something is
/// queued/scheduled, not its own details (see `SubscriptionPlan`'s cases).
private struct UpcomingPeriodPayload: Decodable {
    let tierName: String
}

private struct PendingSwitchPayload: Decodable {
    let tierName: String
}

private struct AdminUsagePayload: Decodable {
    let sessionUsd: Double
    let weeklyUsd: Double
    let last30DaysUsd: Double
    let allTimeUsd: Double
}

/// `GET`/`POST /api/privacy`'s shared shape (`ChatController.GetPrivacy`/
/// `SetPrivacy` — there is no dedicated privacy controller).
private struct PrivacyPayload: Decodable {
    let trainingOptOut: Bool
}

private struct PrivacyUpdateBody: Encodable {
    let trainingOptOut: Bool
}

/// Parses a wire date string defensively: confirmed directly against the
/// real backend that `GET /api/billing` uses .NET's default
/// `System.Text.Json` `DateTime` serialization, which omits the fractional-
/// seconds component entirely when there is none and doesn't pad it to a
/// fixed width when there is — so a single fixed `ISO8601DateFormatter`
/// configuration isn't guaranteed to parse every value it can send. Tries
/// with fractional seconds first, then without.
private enum WireDate {
    static func parse(_ string: String) -> Date? {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractionalSeconds.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
