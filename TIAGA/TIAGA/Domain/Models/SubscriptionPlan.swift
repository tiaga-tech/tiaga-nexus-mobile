//
//  SubscriptionPlan.swift
//  TIAGA
//

import Foundation

/// An operator's billing plan, backing the Settings screen's read-only
/// Billing section. Plan changes (upgrading, redeeming a code, cancelling)
/// only happen on the web version — see `AGENTS.md`'s Billing section notes
/// — so this app only ever reads this, never writes it.
enum SubscriptionPlan: Equatable, Sendable {
    case active(ActivePlan)
    case none
}

/// Real-world event: an active plan always ends on some date — what happens
/// next (`renewalStatus`) depends on auto-renew, a queued follow-on period,
/// or an already-purchased downgrade waiting to take effect.
struct ActivePlan: Equatable, Sendable {
    let tierName: String
    let endsAt: Date
    let renewalStatus: RenewalStatus

    /// Business rule (matches `BillingPanel.tsx`'s exact precedence): a
    /// pending downgrade always takes priority in what's shown, even if
    /// there's also queued time or auto-renew is on — those become moot
    /// once a switch is already scheduled. Queued time beats auto-renew
    /// for the same reason (the current plan isn't what's actually
    /// determining what happens at `endsAt` once something's stacked
    /// behind it).
    enum RenewalStatus: Equatable, Sendable {
        /// A downgrade has already been purchased and is waiting for the
        /// current plan to end.
        case switchingTo(tierName: String)
        /// More plan time is queued (stacked codes) to start when this
        /// period ends.
        case queued
        /// Billed automatically; will renew at `endsAt`.
        case renewing
        /// Not auto-renewing (or not Stripe-billed) — simply ends.
        case ending
    }
}
