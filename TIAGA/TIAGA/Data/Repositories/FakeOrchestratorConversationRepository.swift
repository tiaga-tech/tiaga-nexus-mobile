//
//  FakeOrchestratorConversationRepository.swift
//  TIAGA
//

import Foundation

/// Fixture-backed `OrchestratorConversationRepository` — plain Swift values
/// held in memory, no network calls, no LLM, ever. See CLAUDE.md's "Testing
/// safety: no live backend" policy.
///
/// The canned replies arrive after an artificial short delay so the
/// streaming/busy state is genuinely exercised by the UI, and the context
/// usage follows a scripted ramp (normal → high → critical) so both the 75%
/// and 100% colour thresholds are reachable while exploring the simulator.
final class FakeOrchestratorConversationRepository: OrchestratorConversationRepository, @unchecked Sendable {

    /// How long a fake reply takes to "stream" before it appears.
    private let responseDelayNanoseconds: UInt64

    /// Test/QA hook: force `isStreaming` to true without starting a reply.
    var shouldSimulateStreaming = false

    /// Test/QA hook: make `fetchDynamicUICardHistory()` fail.
    var shouldFailDynamicUICardHistory = false

    private let lock = NSLock()
    private var messages: [ChatMessage]
    private var dynamicUICards: [DynamicUICard]
    private var contextUsageFraction: Double
    private var isReplyStreaming = false
    private var transcriptContinuations: [UUID: AsyncStream<[ChatMessage]>.Continuation] = [:]
    private var usageContinuations: [UUID: AsyncStream<ConversationContextUsage>.Continuation] = [:]

    init(responseDelayNanoseconds: UInt64 = 250_000_000) {
        self.responseDelayNanoseconds = responseDelayNanoseconds

        let now = Date()
        self.messages = [
            ChatMessage(
                role: .orchestrator,
                text: "Fleet console ready. What are we working on?",
                sentAt: now.addingTimeInterval(-420)
            ),
            ChatMessage(
                role: .operator,
                text: "How is the landing page build going?",
                sentAt: now.addingTimeInterval(-360)
            ),
            ChatMessage(
                role: .orchestrator,
                kind: .tool,
                text: "agent: Redesigning the landing page",
                sentAt: now.addingTimeInterval(-330)
            ),
            ChatMessage(
                role: .orchestrator,
                kind: .tool,
                text: "bash: xcodebuild build",
                sentAt: now.addingTimeInterval(-300)
            ),
            ChatMessage(
                role: .orchestrator,
                text: "Atlas finished the landing page build a minute ago — it's green.",
                sentAt: now.addingTimeInterval(-240)
            ),
            // The orchestrator's own conversation can carry an error too, not
            // just an agent's — e.g. a backend hiccup unrelated to any one
            // agent's task. Mirrors the real web client's `kind: 'error'`.
            ChatMessage(
                role: .orchestrator,
                kind: .error,
                text: "The server restarted while agents were working. Their progress is saved.",
                sentAt: now.addingTimeInterval(-180)
            ),
        ]
        self.dynamicUICards = [
            DynamicUICard(
                id: "ui-1",
                title: "Landing page build",
                kind: .text,
                text: "Build finished on Home PC.",
                code: nil,
                language: nil,
                columns: nil,
                rows: nil,
                diagram: nil
            ),
            DynamicUICard(
                id: "ui-2",
                title: "Build command",
                kind: .code,
                text: nil,
                code: "xcodebuild -project TIAGA.xcodeproj -scheme TIAGA build",
                language: "bash",
                columns: nil,
                rows: nil,
                diagram: nil
            ),
            DynamicUICard(
                id: "ui-5",
                title: "Swift snippet",
                kind: .code,
                text: nil,
                code: "struct Agent {\n    let name: String\n    var state: AgentState\n    // Idle agents are ready for work.\n    var isAvailable: Bool {\n        state == .idle\n    }\n}",
                language: "swift",
                columns: nil,
                rows: nil,
                diagram: nil
            ),
            DynamicUICard(
                id: "ui-3",
                title: "Fleet status",
                kind: .table,
                text: nil,
                code: nil,
                language: nil,
                columns: ["Device", "Agents", "Status"],
                rows: [
                    ["Home PC", "Atlas", "Online"],
                    ["Work Laptop", "Comet", "Compacting"],
                ],
                diagram: nil
            ),
            DynamicUICard(
                id: "ui-4",
                title: "Agent lifecycle",
                kind: .diagram,
                text: nil,
                code: nil,
                language: nil,
                columns: nil,
                rows: nil,
                diagram: "graph TD; A[Idle]-->B[Running]; B-->C[Compacting]; C-->B;"
            ),
        ]
        self.contextUsageFraction = 0.42
    }

    var isStreaming: Bool {
        lock.withLock {
            shouldSimulateStreaming || isReplyStreaming
        }
    }

    func send(_ text: String, to target: ConversationTarget) async throws {
        guard !isStreaming else {
            throw SendChatMessageError.conversationBusy
        }

        let now = Date()
        lock.withLock {
            messages.append(
                ChatMessage(role: .operator, text: text, sentAt: now)
            )
            isReplyStreaming = true
        }
        publishTranscript()
        publishContextUsage()

        // The fake "streams" for a moment so the composer visibly enters its
        // busy state before the canned reply lands.
        try? await Task.sleep(nanoseconds: responseDelayNanoseconds)

        let replyAt = Date()
        lock.withLock {
            messages.append(
                ChatMessage(
                    role: .orchestrator,
                    text: Self.reply(for: messages.count),
                    sentAt: replyAt
                )
            )
            contextUsageFraction = Self.nextContextUsage(after: contextUsageFraction)
            isReplyStreaming = false
        }
        publishTranscript()
        publishContextUsage()
    }

    func observeTranscript() -> AsyncStream<[ChatMessage]> {
        let id = UUID()
        return AsyncStream { continuation in
            lock.withLock {
                transcriptContinuations[id] = continuation
            }
            continuation.yield(snapshotTranscript())

            // Keep the stream alive until the subscriber cancels it; events
            // are published from `send`/`resetConversation`.
            let keepAlive = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                }
                _ = self
            }
            continuation.onTermination = { [weak self] _ in
                keepAlive.cancel()
                self?.removeTranscriptContinuation(id)
            }
        }
    }

    func observeContextUsage() -> AsyncStream<ConversationContextUsage> {
        let id = UUID()
        return AsyncStream { continuation in
            lock.withLock {
                usageContinuations[id] = continuation
            }
            continuation.yield(currentContextUsage())

            let keepAlive = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                }
                _ = self
            }
            continuation.onTermination = { [weak self] _ in
                keepAlive.cancel()
                self?.removeUsageContinuation(id)
            }
        }
    }

    func resetConversation() async throws {
        guard !isStreaming else {
            throw ResetConversationError.conversationBusy
        }

        lock.withLock {
            messages.removeAll()
            dynamicUICards.removeAll()
            contextUsageFraction = 0
        }
        publishTranscript()
        publishContextUsage()
    }

    func fetchDynamicUICardHistory() async throws -> [DynamicUICard] {
        if shouldFailDynamicUICardHistory {
            throw DynamicUICardHistoryError.unavailable
        }
        return lock.withLock { dynamicUICards }
    }

    // MARK: - Fixture scripting

    private static func reply(for messageCount: Int) -> String {
        let replies = [
            "On it. Checking the fleet and current agents now.",
            "Agents are still running — I'll report back the moment anything needs your approval.",
            "Builds are green. Nothing is waiting on you right now.",
        ]
        return replies[(messageCount / 2) % replies.count]
    }

    private static func nextContextUsage(after fraction: Double) -> Double {
        switch fraction {
        case ..<ConversationContextUsage.highThreshold:
            return 0.78
        default:
            return 1.0
        }
    }

    // MARK: - Thread-safe snapshots and publishing

    private func snapshotTranscript() -> [ChatMessage] {
        lock.withLock { messages.sorted { $0.sentAt < $1.sentAt } }
    }

    private func currentContextUsage() -> ConversationContextUsage {
        lock.withLock {
            ConversationContextUsage(fraction: contextUsageFraction)
        }
    }

    private func publishTranscript() {
        let snapshot = snapshotTranscript()
        let continuations = lock.withLock { Array(transcriptContinuations.values) }
        for continuation in continuations {
            continuation.yield(snapshot)
        }
    }

    private func publishContextUsage() {
        let usage = currentContextUsage()
        let continuations = lock.withLock { Array(usageContinuations.values) }
        for continuation in continuations {
            continuation.yield(usage)
        }
    }

    private func removeTranscriptContinuation(_ id: UUID) {
        lock.withLock { transcriptContinuations[id] = nil }
    }

    private func removeUsageContinuation(_ id: UUID) {
        lock.withLock { usageContinuations[id] = nil }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
