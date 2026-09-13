//
//  Agent.swift
//  TIAGA
//

import Foundation

/// A stable identifier for a persistent agent.
struct AgentIdentifier: Hashable, Equatable, CustomStringConvertible {
    let rawValue: String
    var description: String { rawValue }
}

/// A persistent, named AI worker the operator has dispatched onto the fleet
/// to do real work (write code, run builds, manage processes).
///
/// Business Rule: an agent is pinned to exactly one device from spawn and
/// never moves — a task that spans two machines becomes two agents by
/// design, not one agent relocating.
struct Agent: Identifiable, Equatable {
    let id: AgentIdentifier
    let name: String
    let state: AgentState
    /// The pinned device's display name — not a `DeviceIdentifier`. Checked
    /// directly against the real backend (`CardsController.cs`'s `tasks`
    /// projection and every `AgentManager` `task` event): an agent's wire
    /// payload only ever carries its pinned device's name and OS, never an
    /// actual device id, so there is no real id here to model.
    let pinnedDeviceName: String
    let lastActivitySummary: String
    let lastActivityAt: Date
    /// 0...1 — how full this agent's context window is. The same domain
    /// concept `TIAGAColor.forContextUsage` colors on the Chat context bar.
    let contextUsageFraction: Double
}
