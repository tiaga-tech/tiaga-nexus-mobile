//
//  UsageSummary.swift
//  TIAGA
//

import Foundation

/// How much of an operator's usage allowance is used up, backing the
/// Settings screen's Usage section.
///
/// Real-world event: the backend's single `/api/billing` response
/// (`BillingInfo` in `web/src/lib/api.ts`) resolves to exactly one of three
/// mutually exclusive states — this isn't three independent flags, it's one
/// account always being in exactly one of them. An admin account has no
/// plan limits, so it sees what its usage actually costs in dollars instead
/// of a percentage. A subscribed account sees percentage meters for the
/// current rolling 5-hour session and the current week, plus any
/// non-expiring extra-credits balance (spent only past those limits). An
/// account with no active plan sees neither meter, only its extra-credits
/// balance if it has one.
enum UsageSummary: Equatable, Sendable {
    case admin(AdminUsage)
    case subscription(SubscriptionUsage)
    case noActivePlan(extraCreditsUsd: Double)
}

/// Real dollar cost for an admin account, which has no plan limits to meter
/// usage against. Regular accounts never receive dollar figures for this —
/// only percentages (see `SubscriptionUsage`). Field names match the wire
/// exactly (`BillingInfo.adminUsage`); `weeklyUsd` is shown as "Past 7 days"
/// in the web client's own UI, not "weekly" — same field, different label.
struct AdminUsage: Equatable, Sendable {
    let sessionUsd: Double
    let weeklyUsd: Double
    let last30DaysUsd: Double
    let allTimeUsd: Double
}

/// Percentage-based usage for a subscribed account. `sessionPercentage` and
/// `weeklyPercentage` are already 0...100 (matching the wire and the real
/// web client's own `Math.round`), not a 0...1 fraction.
struct SubscriptionUsage: Equatable, Sendable {
    let sessionPercentage: Double
    /// When the session window fully resets to zero. `nil` when there's no
    /// usage in the window yet.
    let sessionResetsAt: Date?
    let weeklyPercentage: Double
    let weeklyResetsAt: Date?
    /// The non-expiring extra-credits wallet, in dollars — the one dollar
    /// figure a regular (non-admin) account ever sees, spent only once the
    /// session/weekly limits fill up.
    let extraCreditsUsd: Double
}
