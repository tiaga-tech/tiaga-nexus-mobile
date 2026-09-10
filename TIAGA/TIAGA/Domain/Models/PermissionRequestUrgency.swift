//
//  PermissionRequestUrgency.swift
//  TIAGA
//

import Foundation

/// How close a pending `PermissionRequest` is to auto-denial.
///
/// A protected device blocks sensitive tool calls (bash, write, edit, run_app,
/// kill_process) behind an operator approval. An unanswered request auto-denies
/// after 5 minutes so a stalled agent never blocks forever, but that also means
/// an operator who doesn't act in time silently loses the chance to approve —
/// this type exists so the UI can escalate the visual urgency before that happens.
///
/// Business Rule: a request becomes `.expiringSoon` inside the final 60 seconds
/// of its 5-minute approval window.
enum PermissionRequestUrgency: Equatable {
    case normal
    case expiringSoon
}
