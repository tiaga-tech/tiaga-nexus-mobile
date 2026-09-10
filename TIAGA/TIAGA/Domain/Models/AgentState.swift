//
//  AgentState.swift
//  TIAGA
//

import Foundation

/// The lifecycle state of a persistent AI agent dispatched onto a fleet device.
///
/// Represents the same state machine the harness reports to the backend:
/// an agent is created idle, moves to `running` while executing a task,
/// may be forced into `compacting` when its context window fills, and can
/// end a task in `error`.
///
/// Business Rule: An agent in `.compacting` cannot accept a new instruction —
/// its history is being summarised into a self-handoff briefing and it must
/// finish that transition before it can resume work. See
/// `DispatchAgentTaskUseCase`.
enum AgentState: Equatable {
    /// Not currently working; ready to accept a new instruction.
    case idle
    /// Actively executing a task on its pinned device.
    case running
    /// Mid auto-compaction: its history is being summarised so the task can continue
    /// without dying at the context window limit.
    case compacting
    /// The last task ended in failure. `reason` is the operator-facing summary
    /// carried in the agent's last task report.
    case error(reason: String)
}
