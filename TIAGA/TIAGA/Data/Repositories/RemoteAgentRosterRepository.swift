//
//  RemoteAgentRosterRepository.swift
//  TIAGA
//

import Foundation

/// Talks to the real backend's `CardsController` (`GET /api/cards`'s `tasks`
/// field — there is no dedicated `GET /api/agents` list; checked directly,
/// the agent roster snapshot rides along with dynamic UI cards) and
/// `AgentsController` (`POST /api/agents/{id}/cancel`,
/// `DELETE /api/agents/{id}`), plus the shared `/api/events` SSE stream's
/// `type: "task"` events for live state. See AGENTS.md's "Live backend"
/// policy — this is what `SideMenuViewModel`/`AgentChatViewModel` run
/// against outside Xcode Previews.
///
/// **Simplification**: the wire also carries a live per-agent context
/// percentage over separate `type: "usage", scope: "agent"` events, but
/// nothing in this app's UI currently renders `Agent.contextUsageFraction`
/// (checked every agent-facing screen) — so this repository only populates
/// it from `listAgents()`'s own snapshot, not a live subscription. Revisit
/// if/when an Agent Chat context bar gets built.
final class RemoteAgentRosterRepository: AgentRosterRepository, @unchecked Sendable {
    private let apiClient: TIAGAAPIClient
    private let eventBus: RemoteEventBus

    private let lock = NSLock()
    private var agentsByID: [AgentIdentifier: Agent] = [:]
    private var agentOrder: [AgentIdentifier] = []
    private var isConnected = false
    private var agentContinuations: [AgentIdentifier: [UUID: AsyncStream<Agent>.Continuation]] = [:]
    private var rosterChangeContinuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    init(apiClient: TIAGAAPIClient = TIAGAAPIClient(), eventBus: RemoteEventBus = .shared) {
        self.apiClient = apiClient
        self.eventBus = eventBus
    }

    func listAgents() async throws -> [Agent] {
        connectIfNeeded()
        let payload: CardsListPayload
        do {
            payload = try await apiClient.get("cards")
        } catch {
            throw AgentRosterError.fleetUnreachable
        }

        let now = Date()
        let agents: [Agent] = lock.withLock {
            payload.tasks.map { task in
                // A fresh fetch shouldn't reshuffle the menu's order every
                // time it re-runs — keep whatever "last activity" moment
                // this repository already tracked for a known agent, and
                // only stamp `now` for one it's never seen before. See the
                // type's own doc comment: the real backend has no per-agent
                // timestamp to report at all.
                let lastActivityAt = agentsByID[task.identifier]?.lastActivityAt ?? now
                return task.toDomain(lastActivityAt: lastActivityAt)
            }
        }
        lock.withLock {
            agentsByID = Dictionary(uniqueKeysWithValues: agents.map { ($0.id, $0) })
            agentOrder = agents.map(\.id)
        }
        return agents
    }

    func observeAgent(_ id: AgentIdentifier) -> AsyncStream<Agent> {
        connectIfNeeded()
        let subscriptionID = UUID()
        return AsyncStream { continuation in
            self.lock.withLock { self.agentContinuations[id, default: [:]][subscriptionID] = continuation }
            if let current = self.lock.withLock({ self.agentsByID[id] }) {
                continuation.yield(current)
            }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.agentContinuations[id]?[subscriptionID] = nil }
            }
        }
    }

    /// See the protocol's doc comment — a pulse only; subscribers re-fetch
    /// with `listAgents()`.
    func observeRosterChanges() -> AsyncStream<Void> {
        connectIfNeeded()
        let subscriptionID = UUID()
        return AsyncStream { continuation in
            self.lock.withLock { self.rosterChangeContinuations[subscriptionID] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.rosterChangeContinuations[subscriptionID] = nil }
            }
        }
    }

    func cancelActiveTask(for id: AgentIdentifier) async throws {
        do {
            try await apiClient.postExpectingNoContent("agents/\(id.rawValue)/cancel")
        } catch {
            throw AgentLifecycleError.agentNoLongerExists
        }
    }

    func delete(_ id: AgentIdentifier) async throws {
        do {
            try await apiClient.deleteExpectingNoContent("agents/\(id.rawValue)")
        } catch {
            throw AgentLifecycleError.agentNoLongerExists
        }
        lock.withLock {
            agentsByID[id] = nil
            agentOrder.removeAll { $0 == id }
        }
        publishRosterPulse()
    }

    // MARK: - Live updates

    private func connectIfNeeded() {
        let alreadyConnected = lock.withLock {
            defer { isConnected = true }
            return isConnected
        }
        guard !alreadyConnected else { return }

        // `self` must stay weak for the whole closure — an outer
        // `guard let self` before the loop would shadow it with a
        // permanently-strong local, leaking a "zombie" repository instance
        // that stays subscribed forever. See the identical fix and full
        // explanation in RemoteOrchestratorConversationRepository
        // .connectIfNeeded(), confirmed with NSLog + `log stream`.
        Task { [weak self] in
            guard let eventBus = self?.eventBus else { return }
            for await data in eventBus.events(ofType: "task") {
                guard let self else { return }
                self.handle(data)
            }
        }
    }

    private func handle(_ data: Data) {
        guard let event = try? JSONDecoder().decode(TaskEventPayload.self, from: data),
              let rawID = event.id else { return }
        let id = AgentIdentifier(rawValue: rawID)

        if event.action == "deleted" {
            lock.withLock {
                agentsByID[id] = nil
                agentOrder.removeAll { $0 == id }
            }
            publishRosterPulse()
            return
        }

        // Transient tool-call cards (`OpenRouterLlmClient.cs`'s own direct
        // tool calls, not an agent) ride the same `task` event type with no
        // `name` field and `transient: true` — never a real agent.
        guard event.transient != true else { return }

        let existing = lock.withLock { agentsByID[id] }
        // Only a "started" event with a name can introduce a brand-new
        // agent this repository hasn't seen yet; every other action just
        // updates one already known, and is ignored otherwise to avoid a
        // partially-populated entry.
        guard existing != nil || (event.action == "started" && event.name != nil) else { return }

        let state: AgentState
        switch event.action {
        case "started", "renamed": state = .running
        case "compacting": state = .compacting
        case "error": state = .error(reason: event.error ?? existing?.stateReason ?? "")
        case "done": state = .idle
        default: state = existing?.state ?? .idle
        }

        let merged = Agent(
            id: id,
            name: event.name ?? existing?.name ?? rawID,
            state: state,
            pinnedDeviceName: event.device ?? existing?.pinnedDeviceName ?? "",
            lastActivitySummary: event.summary ?? event.title ?? event.error ?? existing?.lastActivitySummary ?? "",
            lastActivityAt: Date(),
            contextUsageFraction: existing?.contextUsageFraction ?? 0
        )

        lock.withLock {
            agentsByID[id] = merged
            if !agentOrder.contains(id) { agentOrder.append(id) }
        }
        publish(id, merged)
        publishRosterPulse()
    }

    private func publish(_ id: AgentIdentifier, _ agent: Agent) {
        let continuations = lock.withLock { Array((agentContinuations[id] ?? [:]).values) }
        for continuation in continuations {
            continuation.yield(agent)
        }
    }

    private func publishRosterPulse() {
        let continuations = lock.withLock { Array(rosterChangeContinuations.values) }
        for continuation in continuations {
            continuation.yield(())
        }
    }
}

private extension Agent {
    /// The existing failure reason, if this agent is currently `.error` —
    /// used to keep a sensible message if a later event updates this agent
    /// without repeating the original `error` text.
    var stateReason: String? {
        if case .error(let reason) = state { return reason }
        return nil
    }
}

// MARK: - Wire payloads

/// `GET /api/cards`'s `tasks` field (`CardsController.List`) — the agent
/// roster snapshot. Shares the response with `ui` (dynamic UI cards, decoded
/// by `RemoteOrchestratorConversationRepository` instead).
private struct CardsListPayload: Decodable {
    let tasks: [AgentTaskPayload]
}

private struct AgentTaskPayload: Decodable {
    let id: String
    let name: String
    let title: String
    let device: String
    let deviceType: String
    let state: String
    let report: String?
    let interrupted: Bool
    let pct: Int

    var identifier: AgentIdentifier { AgentIdentifier(rawValue: id) }

    func toDomain(lastActivityAt: Date) -> Agent {
        let agentState: AgentState
        switch state {
        case "running": agentState = .running
        case "compacting": agentState = .compacting
        case "error": agentState = .error(reason: report ?? "")
        default: agentState = .idle
        }
        // While running/compacting, `title` is the current activity; once
        // idle or errored, `report` holds the finished/failed summary
        // instead (`Agent.Report`'s own dual real-world use — see
        // `AgentManager.cs`'s `Complete`/`Fail`).
        let summary: String
        switch agentState {
        case .running, .compacting: summary = title
        case .idle, .error: summary = report ?? title
        }
        return Agent(
            id: identifier,
            name: name,
            state: agentState,
            pinnedDeviceName: device,
            lastActivitySummary: summary,
            lastActivityAt: lastActivityAt,
            contextUsageFraction: Double(pct) / 100
        )
    }
}

/// One `/api/events` SSE frame of `type: "task"` — a superset of fields
/// across every `action` this repository handles (`AgentManager.cs`'s
/// several publish call sites); a given action only ever populates a subset,
/// the rest decode as `nil`.
private struct TaskEventPayload: Decodable {
    let action: String?
    let id: String?
    let name: String?
    let title: String?
    let device: String?
    let summary: String?
    let error: String?
    let transient: Bool?
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
