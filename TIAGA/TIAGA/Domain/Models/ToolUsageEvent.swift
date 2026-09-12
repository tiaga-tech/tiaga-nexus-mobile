//
//  ToolUsageEvent.swift
//  TIAGA
//

import Foundation

/// A tool call the orchestrator made, shown inline in the transcript.
///
/// Mirrors the backend's live `tool` event (`name` + a human-readable `detail`)
/// and the tool rows in `GetMessageHistory`. A tool row is not something
/// anyone "said" — it is a record of an action, so the UI renders it as a
/// dim monospaced line rather than a chat bubble.
struct ToolUsageEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    /// The harness tool name, e.g. `bash`, `agent`, `add_code_ui`.
    let toolName: String
    /// The device the tool ran on, when the tool is device-scoped.
    let targetDevice: DeviceIdentifier?
    /// The operator-facing, already-humanized summary shown in the transcript.
    let summary: String
    let occurredAt: Date

    init(
        id: UUID = UUID(),
        toolName: String,
        targetDevice: DeviceIdentifier? = nil,
        summary: String,
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.targetDevice = targetDevice
        self.summary = summary
        self.occurredAt = occurredAt
    }
}
