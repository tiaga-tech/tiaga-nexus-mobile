//
//  FakeAgentConversationRepository.swift
//  TIAGA
//

import Foundation

/// Fixture-backed `AgentConversationRepository` — plain Swift values held in
/// memory per agent, no network calls, no LLM, ever. See CLAUDE.md's
/// "Testing safety: no live backend" policy.
///
/// Each agent's conversation is created on first touch (starting empty) and
/// kept independently of every other agent's. Atlas is pre-seeded with a
/// short realistic exchange, and Vega (fixture-errored in
/// `FakeAgentRosterRepository`) is pre-seeded with the error message that
/// explains why — matching the real web client, where an agent's error
/// shows as a message in its own transcript, not just a status pill.
final class FakeAgentConversationRepository: AgentConversationRepository, @unchecked Sendable {

    /// How long a fake reply takes to "arrive" before it appears.
    private let responseDelayNanoseconds: UInt64

    private let lock = NSLock()
    private var messagesByAgent: [AgentIdentifier: [ChatMessage]]
    private var continuations: [UUID: (AgentIdentifier, AsyncStream<[ChatMessage]>.Continuation)] = [:]

    init(responseDelayNanoseconds: UInt64 = 250_000_000) {
        self.responseDelayNanoseconds = responseDelayNanoseconds

        let now = Date()
        let atlas = AgentIdentifier(rawValue: "agent-atlas")
        let vega = AgentIdentifier(rawValue: "agent-vega")
        messagesByAgent = [
            atlas: [
                ChatMessage(
                    role: .orchestrator,
                    text: "I'm redesigning the landing page on Home PC — I'll ping you if anything needs a decision.",
                    sentAt: now.addingTimeInterval(-200)
                ),
                ChatMessage(
                    role: .operator,
                    text: "Use the new hero image in the marketing folder.",
                    sentAt: now.addingTimeInterval(-150)
                ),
                ChatMessage(
                    role: .orchestrator,
                    kind: .tool,
                    text: "edit web/src/App.tsx",
                    sentAt: now.addingTimeInterval(-100)
                ),
                ChatMessage(
                    role: .orchestrator,
                    text: "Done — swapped it in and re-ran the build. Still green.",
                    sentAt: now.addingTimeInterval(-90)
                ),
            ],
            vega: [
                ChatMessage(
                    role: .orchestrator,
                    kind: .tool,
                    text: "bash: npm run build",
                    sentAt: now.addingTimeInterval(-3660)
                ),
                ChatMessage(
                    role: .orchestrator,
                    kind: .error,
                    text: "Build failed",
                    sentAt: now.addingTimeInterval(-3600)
                ),
            ],
        ]
    }

    func send(_ text: String, to agentID: AgentIdentifier) async throws {
        let now = Date()
        lock.withLock {
            messagesByAgent[agentID, default: []].append(
                ChatMessage(role: .operator, text: text, sentAt: now)
            )
        }
        publishTranscript(for: agentID)

        // The fake "replies" for a moment so the composer visibly exercises
        // the round-trip, matching the orchestrator conversation's feel.
        try? await Task.sleep(nanoseconds: responseDelayNanoseconds)

        let replyAt = Date()
        lock.withLock {
            messagesByAgent[agentID, default: []].append(
                ChatMessage(role: .orchestrator, text: "Got it — on it.", sentAt: replyAt)
            )
        }
        publishTranscript(for: agentID)
    }

    func observeTranscript(for agentID: AgentIdentifier) -> AsyncStream<[ChatMessage]> {
        AsyncStream { continuation in
            let subscriptionID = UUID()
            lock.withLock { continuations[subscriptionID] = (agentID, continuation) }
            continuation.yield(snapshotTranscript(for: agentID))

            // Keep the stream alive until the subscriber cancels it; events
            // are published from `send`.
            let keepAlive = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                }
                _ = self
            }
            continuation.onTermination = { [weak self] _ in
                keepAlive.cancel()
                self?.removeContinuation(subscriptionID)
            }
        }
    }

    // MARK: - Thread-safe snapshots and publishing

    private func snapshotTranscript(for agentID: AgentIdentifier) -> [ChatMessage] {
        lock.withLock {
            (messagesByAgent[agentID] ?? []).sorted { $0.sentAt < $1.sentAt }
        }
    }

    private func publishTranscript(for agentID: AgentIdentifier) {
        let snapshot = snapshotTranscript(for: agentID)
        let matchingContinuations = lock.withLock {
            continuations.values.filter { $0.0 == agentID }.map(\.1)
        }
        for continuation in matchingContinuations {
            continuation.yield(snapshot)
        }
    }

    private func removeContinuation(_ id: UUID) {
        lock.withLock { continuations[id] = nil }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
