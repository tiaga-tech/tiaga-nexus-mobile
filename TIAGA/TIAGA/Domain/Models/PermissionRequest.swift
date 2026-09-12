//
//  PermissionRequest.swift
//  TIAGA
//

import Foundation

/// What kind of sensitive action a `PermissionRequest` is gating. Matches
/// the real backend's own categorization (`PermissionManager.cs`'s
/// `Describe`) — a `command` covers `bash`/`run_app`/`kill_process`, `write`
/// covers the `write` tool, and `edit` covers the `edit` tool (which also
/// carries structured per-file `edits` for a diff view).
enum PermissionRequestKind: String, Equatable, Sendable {
    case command
    case write
    case edit
}

/// One replacement within a file, part of an `edit` request's diff.
struct PermissionRequestEdit: Equatable, Sendable {
    let old: String
    let new: String
}

/// One file's ordered edits, for a future tabbed diff view. Only ever
/// present on an `.edit`-kind request.
struct PermissionRequestFile: Identifiable, Equatable, Sendable {
    var id: String { path }
    let path: String
    let edits: [PermissionRequestEdit]
}

/// An approval prompt raised when the orchestrator or an agent on a
/// protected device wants to run a sensitive tool.
///
/// Business Rule: there is no timeout — the real backend blocks the
/// gated call indefinitely until the operator explicitly approves or
/// denies it (see `PermissionManager.cs`: "No time limit... the overlay is
/// non-dismissable, so it can't be silently lost"). It only resolves
/// without an explicit answer if the underlying call is cancelled (an
/// agent/turn stop), which the backend treats as a cancellation, not a
/// denial — this app has no cancellation-triggered auto-resolution either,
/// since a request just disappears from the pending list when that happens
/// server-side.
struct PermissionRequest: Identifiable, Equatable, Sendable {
    let id: String
    let deviceID: DeviceIdentifier
    let deviceName: String
    /// Who's asking — an agent's name, or "TIAGA" for the orchestrator
    /// itself. A plain display string, not an `AgentIdentifier` reference:
    /// the real backend never resolves this against the agent roster either.
    let requester: String
    let tool: String
    let kind: PermissionRequestKind
    let file: String?
    let detail: String
    let files: [PermissionRequestFile]?
}
