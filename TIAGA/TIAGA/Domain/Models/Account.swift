//
//  Account.swift
//  TIAGA
//

import Foundation

/// A signed-in TIAGA user.
///
/// Represents the real backend's `User` entity as seen by the operator's own
/// device — the same account can be signed in on the desktop client, the web
/// client, and this app at once, since auth is session-based per account, not
/// per device.
///
/// Business Rule: authentication succeeding does not imply product access —
/// see `AccountStatus`. `roles` is an additive set (an account can hold
/// several at once), mirroring the real backend's admin/developer role model.
struct Account: Equatable {
    let email: String
    let status: AccountStatus
    let roles: Set<AccountRole>
}

/// A capability grant layered on top of a `.active` account. Additive, not
/// exclusive — matches the real backend's `ADMIN_EMAILS`/`DEVELOPER_EMAILS`
/// promotion model (`AuthService.cs`).
enum AccountRole: String, Equatable {
    /// Unlimited usage; access to the admin panel (the panel itself is not
    /// surfaced in this app, but Settings' Usage section does show an admin
    /// account's real dollar cost instead of a percentage — see
    /// `UsageSummary.admin`).
    case admin
    /// Access to the `/logs` page. Not surfaced in this app.
    case developer
}
