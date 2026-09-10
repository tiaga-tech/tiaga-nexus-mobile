//
//  AccountStatus.swift
//  TIAGA
//

import Foundation

/// Where a TIAGA account stands relative to the product's private beta.
///
/// Exactly mirrors the real backend's two account states (`AuthUser.status`
/// in the web client) — do not add states it doesn't have.
///
/// Business Rule: authenticating successfully does not imply product access.
/// A `.waitlisted` account has a valid session but must see the waitlist
/// gate, not the fleet console, until an invite code redemption (or admin
/// approval) flips it to `.active`.
enum AccountStatus: String, Equatable {
    case waitlisted
    case active
}
