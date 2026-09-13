//
//  RemoteAgentConversationRepository.swift
//  TIAGA
//

import Foundation

/// Talks to the real backend's direct user↔agent chat endpoints
/// (`AgentsController`'s `GET`/`POST /api/agents/{id}/chat`,
/// `POST .../interrupt`, `POST .../handback`), plus the shared
/// `/api/events` SSE stream's `type: "agent_chat"` events for live updates
/// while the chat is open. See AGENTS.md's "Live backend" policy — this is
/// what `AgentChatViewModel` runs against outside Xcode Previews.
///
/// **A meaningfully different shape from the orchestrator's own
/// `RemoteOrchestratorConversationRepository`**: `POST .../chat` is a
/// synchronous request/response — it returns the agent's reply directly in
/// the same response, unlike the orchestrator's fire-and-forget `POST /api/chat`
/// (everything over SSE). Checked `AgentsController.cs`/`OpenRouterLlmClient
/// .ChatWithAgentAsync` directly. The live `agent_chat` SSE event can still
/// deliver the identical reply a second time (the backend publishes it for
/// every OTHER open viewer too) — `appendAndPublish` dedupes an exact repeat
/// of the transcript's last message, matching `useAgentChat.ts`'s own
/// `appendMsg`.
///
/// **Real fidelity limit, not a client bug to work around**: a tool call
/// made *during* a direct-chat turn isn't published live anywhere — checked,
/// `ChatWithAgentAsync` never emits an `agent_chat` event for one. It only
/// becomes visible via `GetAgentChat`'s persisted history, i.e. the next
/// time this agent's chat is opened (`observeTranscript`'s seed step).
final class RemoteAgentConversationRepository: AgentConversationRepository, @unchecked Sendable {
    private let apiClient: TIAGAAPIClient
    private let eventBus: RemoteEventBus

    private let lock = NSLock()
    private var messagesByAgent: [AgentIdentifier: [ChatMessage]] = [:]
    private var seededAgents: Set<AgentIdentifier> = []
    private var isConnected = false
    private var continuationsByAgent: [AgentIdentifier: [UUID: AsyncStream<[ChatMessage]>.Continuation]] = [:]

    init(apiClient: TIAGAAPIClient = TIAGAAPIClient(), eventBus: RemoteEventBus = .shared) {
        self.apiClient = apiClient
        self.eventBus = eventBus
    }

    func send(_ text: String, to agentID: AgentIdentifier) async throws {
        let operatorMessage = ChatMessage(role: .operator, text: text)
        appendAndPublish(operatorMessage, for: agentID)

        do {
            let response: AgentChatResponsePayload = try await apiClient.post(
                "agents/\(agentID.rawValue)/chat",
                body: AgentChatRequestBody(message: text)
            )
            // An empty/absent reply means the turn failed after being
            // accepted (usage ran out, a permission was denied, a generic
            // error) — the backend published the actual explanation as a
            // role:"error" `agent_chat` SSE event instead of returning it
            // here, and the live subscription started by `observeTranscript`
            // picks that up separately. Matches `useAgentChat.ts`'s own
            // reliance on the POST response for the happy path only.
            if let reply = response.reply, !reply.isEmpty {
                appendAndPublish(ChatMessage(role: .orchestrator, text: reply), for: agentID)
            }
        } catch {
            removeMessage(id: operatorMessage.id, for: agentID)
            if case APITransportError.serverError(409, _) = error {
                // The agent started running between the roster's busy-check
                // and this POST landing — a benign race the backend itself
                // treats as ordinary conflict (409), not a fault. See
                // `SendChatMessageUseCase`'s own pre-check for the common
                // case this only rarely slips past.
                throw SendChatMessageError.conversationBusy
            }
            if case APITransportError.serverError(let status, let message) = error, status == 403 || status == 429 {
                throw SendChatMessageError.rejectedByBackend(reason: message ?? "TIAGA is unavailable right now.")
            }
            throw SendChatMessageError.rejectedByBackend(
                reason: "Can't reach TIAGA right now. Please check your connection and try again."
            )
        }
    }

    func observeTranscript(for agentID: AgentIdentifier) -> AsyncStream<[ChatMessage]> {
        connectIfNeeded()
        seedIfNeeded(agentID)
        let subscriptionID = UUID()
        return AsyncStream { continuation in
            self.lock.withLock { self.continuationsByAgent[agentID, default: [:]][subscriptionID] = continuation }
            continuation.yield(self.lock.withLock { self.messagesByAgent[agentID] ?? [] })
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.continuationsByAgent[agentID]?[subscriptionID] = nil }
            }
        }
    }

    func interruptActiveTask(for agentID: AgentIdentifier) async throws {
        do {
            try await apiClient.postExpectingNoContent("agents/\(agentID.rawValue)/interrupt")
        } catch {
            throw AgentLifecycleError.agentNoLongerExists
        }
    }

    func endChat(with agentID: AgentIdentifier) async {
        try? await apiClient.postExpectingNoContent("agents/\(agentID.rawValue)/handback")
    }

    // MARK: - Seeding and live updates

    private func seedIfNeeded(_ agentID: AgentIdentifier) {
        let alreadySeeded = lock.withLock {
            if seededAgents.contains(agentID) { return true }
            seededAgents.insert(agentID)
            return false
        }
        guard !alreadySeeded else { return }

        Task {
            guard let payload: AgentChatHistoryPayload = try? await self.apiClient.get("agents/\(agentID.rawValue)/chat") else { return }
            let seeded = payload.messages.map { $0.toDomain() }
            self.lock.withLock { self.messagesByAgent[agentID] = seeded }
            self.publishTranscript(for: agentID)
        }
    }

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
            for await data in eventBus.events(ofType: "agent_chat") {
                guard let self else { return }
                self.handle(data)
            }
        }
    }

    private func handle(_ data: Data) {
        guard let event = try? JSONDecoder().decode(AgentChatEventPayload.self, from: data),
              let rawID = event.agentId else { return }
        let agentID = AgentIdentifier(rawValue: rawID)

        // Only an agent this app has already opened at least once this
        // session is worth tracking — nothing displays it otherwise, and
        // opening it later re-seeds the full history anyway.
        guard lock.withLock({ messagesByAgent[agentID] != nil }) else { return }

        let message: ChatMessage
        switch event.role {
        case "user": message = ChatMessage(role: .operator, text: event.text ?? "")
        case "agent": message = ChatMessage(role: .orchestrator, text: event.text ?? "")
        case "error": message = ChatMessage(role: .orchestrator, kind: .error, text: event.text ?? "")
        default: return
        }
        appendAndPublish(message, for: agentID)
    }

    // MARK: - Thread-safe publish

    /// Skips an exact repeat of the transcript's last message — the reply
    /// arriving over both the POST response and the SSE echo (or the
    /// operator's own message echoed as role "user") is only shown once,
    /// matching `useAgentChat.ts`'s `appendMsg`.
    private func appendAndPublish(_ message: ChatMessage, for agentID: AgentIdentifier) {
        let didAppend = lock.withLock { () -> Bool in
            var messages = messagesByAgent[agentID] ?? []
            if let last = messages.last, last.role == message.role, last.text == message.text {
                return false
            }
            messages.append(message)
            messagesByAgent[agentID] = messages
            return true
        }
        guard didAppend else { return }
        publishTranscript(for: agentID)
    }

    private func removeMessage(id: UUID, for agentID: AgentIdentifier) {
        lock.withLock { messagesByAgent[agentID]?.removeAll { $0.id == id } }
        publishTranscript(for: agentID)
    }

    private func publishTranscript(for agentID: AgentIdentifier) {
        let snapshot = lock.withLock { messagesByAgent[agentID] ?? [] }
        let continuations = lock.withLock { Array((continuationsByAgent[agentID] ?? [:]).values) }
        for continuation in continuations {
            continuation.yield(snapshot)
        }
    }
}

// MARK: - Wire payloads

private struct AgentChatRequestBody: Encodable {
    let message: String
}

/// `POST /api/agents/{id}/chat`'s success response (`AgentsController.Chat`)
/// — an empty/absent `reply` means the turn failed after being accepted; see
/// this file's own doc comment.
private struct AgentChatResponsePayload: Decodable {
    let reply: String?
}

/// `GET /api/agents/{id}/chat`'s shape (`AgentsController.GetChat` /
/// `OpenRouterLlmClient.GetAgentChat`). `role` is one of "user"/"agent"/
/// "tool"/"error" — richer than the live `agent_chat` SSE event, since a
/// reload also reconstructs any tool calls made during a past turn.
private struct AgentChatHistoryPayload: Decodable {
    let messages: [AgentChatMessagePayload]
}

private struct AgentChatMessagePayload: Decodable {
    let role: String
    let text: String

    func toDomain() -> ChatMessage {
        switch role {
        case "user": return ChatMessage(role: .operator, text: text)
        case "tool": return ChatMessage(role: .orchestrator, kind: .tool, text: text)
        case "error": return ChatMessage(role: .orchestrator, kind: .error, text: text)
        default: return ChatMessage(role: .orchestrator, text: text) // "agent"
        }
    }
}

/// One `/api/events` SSE frame of `type: "agent_chat"`
/// (`ChatWithAgentAsync`'s several `hub.PublishAsync` call sites).
private struct AgentChatEventPayload: Decodable {
    let agentId: String?
    let role: String?
    let text: String?
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
