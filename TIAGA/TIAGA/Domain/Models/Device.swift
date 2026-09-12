//
//  Device.swift
//  TIAGA
//

import Foundation

/// A device's auto-detected operating system, reported by the harness — not
/// something the operator sets. Raw values match the real backend's own
/// lowercase wire values exactly (see `DeviceManager.cs`'s
/// `d.Type.ToString().ToLowerInvariant()`).
enum DeviceType: String, Equatable, Sendable {
    case mac
    case windows
    case linux
}

/// A machine with the TIAGA harness installed, reachable to receive agent
/// work.
///
/// Business Rule: `isOnline` is a live, event-driven flag the harness flips
/// on connect/disconnect — not something derived client-side from a
/// last-seen timestamp. The real backend has no staleness heuristic either
/// (see `DeviceManager.cs`: `Online` is only ever set `true` on connect and
/// `false` on disconnect, never computed from a timestamp), so this app
/// trusts the same plain boolean rather than inventing its own derivation.
struct Device: Identifiable, Equatable, Sendable {
    let id: DeviceIdentifier
    let name: String
    let type: DeviceType
    let isOnline: Bool
    /// Matches the real backend's `PermissionsRequired` exactly (defaults to
    /// `true` there — see `DeviceManager.cs`). When `true`, this device gates
    /// sensitive tools (`bash`, `write`, `edit`, `run_app`, `kill_process`)
    /// behind a `PermissionRequest` instead of letting an agent run them
    /// freely; when `false`, they run automatically without approval.
    let permissionsRequired: Bool
}
