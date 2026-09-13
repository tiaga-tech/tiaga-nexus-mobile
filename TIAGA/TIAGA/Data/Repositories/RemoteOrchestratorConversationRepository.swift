//
//  RemoteOrchestratorConversationRepository.swift
//  TIAGA
//

import Foundation

/// Talks to the real backend's `ChatController` (`/api/messages`,
/// `/api/chat`, `/api/context`, `/api/reset`) and `CardsController`
/// (`/api/cards`, `/api/ui/{id}`), plus the shared `/api/events` SSE stream
/// for everything that happens after a message is sent. See AGENTS.md's
/// "Live backend" policy — this is what `ChatViewModel` runs against
/// outside Xcode Previews.
///
/// **This is the highest-stakes `Remote*Repository` in the app**: a message
/// sent through this reaches a real LLM (real, billed cost) and can
/// dispatch a real tool call onto a real machine.
///
/// `POST /api/chat` is fire-and-forget (`ChatController.Chat`'s own doc
/// comment: "the turn runs asynchronously and all output flows over
/// `/api/events`") — unlike `FakeOrchestratorConversationRepository`, which
/// awaits its whole canned reply cycle inside `send(_:to:)`, this only waits
/// for the POST to be accepted. The operator's own message is appended to
/// the transcript optimistically (matching `useConversation.ts`'s `send`
/// exactly — the backend never echoes it back over SSE), and the actual
/// reply arrives later as `voice`/`tool`/`error` events on the already-
/// running subscription started by `observeTranscript()`.
///
/// **Simplification**: the real backend has a separate `compacting` state
/// (`IsCompacting`) alongside `thinking` (`IsThinking`) — both block new
/// sends, but only `thinking` maps to something this app's UI already shows
/// (`isStreaming`). Rather than inventing a new "compacting" indicator this
/// pass, `compaction` events also drive `isStreaming` — it still correctly
/// blocks sends/resets during compaction, it just reads as "still replying"
/// rather than a distinct label. Revisit if/when a compacting-specific UI
/// gets built.
final class RemoteOrchestratorConversationRepository: OrchestratorConversationRepository, @unchecked Sendable {
    private let apiClient: TIAGAAPIClient
    private let eventBus: RemoteEventBus

    /// Every event type this repository's transcript/usage/busy-state cares
    /// about — matches `useConversation.ts`'s `es.onmessage` switch, minus
    /// the types routed elsewhere (`ui`/`task`/`agent_chat*`/`processes`/
    /// `device`/`permission`/`hello`), which belong to other screens/repos.
    private static let relevantEventTypes: Set<String> = [
        "voice", "tool", "error", "turn_start", "turn_end", "compaction", "usage", "cancelled",
    ]

    private let lock = NSLock()
    private var messages: [ChatMessage] = []
    private var dynamicUICards: [DynamicUICard] = []
    private var contextUsageFraction: Double = 0
    private var isReplyStreaming = false
    private var isConnected = false
    private var transcriptContinuations: [UUID: AsyncStream<[ChatMessage]>.Continuation] = [:]
    private var usageContinuations: [UUID: AsyncStream<ConversationContextUsage>.Continuation] = [:]

    init(apiClient: TIAGAAPIClient = TIAGAAPIClient(), eventBus: RemoteEventBus = .shared) {
        self.apiClient = apiClient
        self.eventBus = eventBus
    }

    var isStreaming: Bool {
        lock.withLock { isReplyStreaming }
    }

    func send(_ text: String, to target: ConversationTarget) async throws {
        let sentAt = Date()
        lock.withLock {
            messages.append(ChatMessage(role: .operator, text: text, sentAt: sentAt))
        }
        publishTranscript()

        do {
            try await apiClient.postExpectingNoContent("chat", body: ChatRequestBody(message: text))
        } catch {
            // Not accepted — drop the optimistic bubble, matching
            // useConversation.ts's `send`: "The message was not accepted,
            // so drop the optimistic user bubble."
            lock.withLock { messages.removeAll { $0.sentAt == sentAt && $0.role == .operator } }
            publishTranscript()
            throw SendChatMessageError.rejectedByBackend(reason: Self.reason(for: error))
        }
    }

    func observeTranscript() -> AsyncStream<[ChatMessage]> {
        connectIfNeeded()
        let id = UUID()
        return AsyncStream { continuation in
            self.lock.withLock { self.transcriptContinuations[id] = continuation }
            continuation.yield(self.lock.withLock { self.messages })
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.transcriptContinuations[id] = nil }
            }
        }
    }

    func observeContextUsage() -> AsyncStream<ConversationContextUsage> {
        connectIfNeeded()
        let id = UUID()
        return AsyncStream { continuation in
            self.lock.withLock { self.usageContinuations[id] = continuation }
            continuation.yield(ConversationContextUsage(fraction: self.lock.withLock { self.contextUsageFraction }))
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.usageContinuations[id] = nil }
            }
        }
    }

    func resetConversation() async throws {
        do {
            try await apiClient.postExpectingNoContent("reset")
        } catch {
            throw ResetConversationError.conversationBusy
        }
        lock.withLock {
            messages.removeAll()
            dynamicUICards.removeAll()
        }
        publishTranscript()
    }

    func fetchDynamicUICardHistory() async throws -> [DynamicUICard] {
        do {
            let payload: CardsListPayload = try await apiClient.get("cards")
            let cards = payload.ui.map { $0.toDomain() }
            lock.withLock { dynamicUICards = cards }
            return cards
        } catch {
            throw DynamicUICardHistoryError.unavailable
        }
    }

    func removeDynamicUICard(id: String) async throws {
        try await apiClient.deleteExpectingNoContent("ui/\(id)")
    }

    // MARK: - Connection

    private func connectIfNeeded() {
        let alreadyConnected = lock.withLock {
            defer { isConnected = true }
            return isConnected
        }
        guard !alreadyConnected else { return }

        Task {
            await self.seed()
            for await data in self.eventBus.events(ofTypes: Self.relevantEventTypes) {
                await self.handle(data)
            }
        }
    }

    /// Initial state on connect: history (so a returning operator sees the
    /// existing conversation, not a blank screen) and context usage/busy
    /// state (so a reload mid-turn restores the disabled composer instead
    /// of pretending TIAGA is idle) — matches `useConversation.ts`'s
    /// `es.onopen` handler exactly.
    private func seed() async {
        async let historyResult: [MessagePayload]? = try? apiClient.get("messages")
        async let contextResult: ContextPayload? = try? apiClient.get("context")
        let history = await historyResult
        let context = await contextResult

        lock.withLock {
            if let history {
                messages = history.map { $0.toDomain() }
            }
            if let context {
                contextUsageFraction = Double(context.pct ?? 0) / 100
                isReplyStreaming = context.thinking == true || context.compacting
            }
        }
        publishTranscript()
        publishContextUsage()
    }

    private func handle(_ data: Data) async {
        guard let event = try? JSONDecoder().decode(ChatEventPayload.self, from: data) else { return }

        switch event.type {
        case "voice":
            // display=false: an audio-only condensation of a longer reply
            // already shown in full — no separate bubble.
            if event.display != false {
                appendAndPublish(ChatMessage(role: .orchestrator, kind: .voice, text: event.text ?? ""))
            }

        case "tool":
            let label = event.detail.map { "\(event.name ?? "tool"): \($0)" } ?? (event.name ?? "tool")
            appendAndPublish(ChatMessage(role: .orchestrator, kind: .tool, text: label))

        case "error":
            lock.withLock { isReplyStreaming = false }
            appendAndPublish(ChatMessage(role: .orchestrator, kind: .error, text: event.text ?? ""))

        case "turn_start":
            lock.withLock { isReplyStreaming = true }
            publishTranscript()

        case "turn_end", "cancelled":
            lock.withLock { isReplyStreaming = false }
            publishTranscript()

        case "compaction":
            if event.state == "start" {
                lock.withLock { isReplyStreaming = true }
                publishTranscript()
            } else {
                // History was rewritten to a compact summary — resync from
                // the backend rather than trying to reconstruct it locally,
                // then add a marker so the (now much shorter) transcript
                // reads as intentional. Matches `useConversation.ts`'s
                // `compaction`-end handler exactly.
                let refreshed: [MessagePayload]? = try? await apiClient.get("messages")
                lock.withLock {
                    isReplyStreaming = false
                    if let refreshed {
                        messages = refreshed.map { $0.toDomain() }
                    }
                    messages.append(ChatMessage(role: .orchestrator, kind: .context, text: "Context compacted to free up space."))
                }
                publishTranscript()
            }

        case "usage":
            if event.scope == "orchestrator", let pct = event.pct {
                lock.withLock { contextUsageFraction = pct / 100 }
                publishContextUsage()
            }

        default:
            break
        }
    }

    private static func reason(for error: Error) -> String {
        if case APITransportError.serverError(_, let message) = error, let message {
            return message
        }
        return "Can't reach TIAGA right now. Please check your connection and try again."
    }

    // MARK: - Thread-safe publish

    private func appendAndPublish(_ message: ChatMessage) {
        lock.withLock { messages.append(message) }
        publishTranscript()
    }

    private func publishTranscript() {
        let snapshot = lock.withLock { messages }
        let continuations = lock.withLock { Array(transcriptContinuations.values) }
        for continuation in continuations {
            continuation.yield(snapshot)
        }
    }

    private func publishContextUsage() {
        let usage = ConversationContextUsage(fraction: lock.withLock { contextUsageFraction })
        let continuations = lock.withLock { Array(usageContinuations.values) }
        for continuation in continuations {
            continuation.yield(usage)
        }
    }
}

// MARK: - Wire payloads

/// `GET /api/messages`'s per-message shape (`ChatController.Messages`).
/// `name`/`detail`/`result` exist on the wire but aren't needed here — the
/// backend already persists `text` fully formatted (confirmed against
/// `MessageList.tsx`, which renders `msg.text` directly, never
/// reconstructing it from `name`/`detail`).
private struct MessagePayload: Decodable {
    let role: String
    let text: String
    let kind: String?

    func toDomain() -> ChatMessage {
        ChatMessage(
            role: role == "user" ? .operator : .orchestrator,
            kind: kind.flatMap(ChatMessageKind.init(rawValue:)) ?? .voice,
            text: text
        )
    }
}

/// `GET /api/context`'s shape (`ChatController.Context`). `pct` is `null`
/// when there's no usage yet.
private struct ContextPayload: Decodable {
    let pct: Int?
    let compacting: Bool
    let thinking: Bool?
}

/// One `/api/events` SSE frame relevant to chat — a superset of fields
/// across every event `type` this repository handles; irrelevant fields for
/// a given type are simply absent and decode as `nil`.
private struct ChatEventPayload: Decodable {
    let type: String
    let text: String?
    let display: Bool?
    let name: String?
    let detail: String?
    let scope: String?
    let pct: Double?
    let state: String?
}

private struct ChatRequestBody: Encodable {
    let message: String
}

/// `GET /api/cards`'s shape (`CardsController.List`) — only `ui` is this
/// repository's concern; `tasks` (agent task cards) belongs to Agent Chat.
private struct CardsListPayload: Decodable {
    let ui: [DynamicCardPayload]
}

/// A `DynamicCard` (`DynamicUiManager.cs`) carries no explicit kind
/// discriminator field — which of the four kinds it is has to be inferred
/// from which optional fields are populated, in the same priority order the
/// web client itself checks them (`FloatingCardsLayer.tsx`): diagram, then
/// code, then a table (columns+rows), else plain text.
private struct DynamicCardPayload: Decodable {
    let id: String
    let title: String
    let text: String?
    let code: String?
    let language: String?
    let columns: [String]?
    let rows: [[String]]?
    let diagram: String?

    func toDomain() -> DynamicUICard {
        let kind: DynamicUICardKind
        if diagram != nil {
            kind = .diagram
        } else if code != nil {
            kind = .code
        } else if columns != nil, rows != nil {
            kind = .table
        } else {
            kind = .text
        }
        return DynamicUICard(
            id: id,
            title: title,
            kind: kind,
            text: text,
            code: code,
            language: language,
            columns: columns,
            rows: rows,
            diagram: diagram
        )
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
