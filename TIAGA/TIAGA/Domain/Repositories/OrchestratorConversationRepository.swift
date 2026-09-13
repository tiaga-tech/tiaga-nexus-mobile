//
//  OrchestratorConversationRepository.swift
//  TIAGA
//

import Foundation

/// The orchestrator conversation's source of truth. Protocol only — see
/// `Data/Repositories/FakeOrchestratorConversationRepository.swift` for the
/// (fixture-backed, no-network) implementation. Never call this directly from
/// a View; go through a Use Case.
protocol OrchestratorConversationRepository {
    /// Adds an operator message and produces a canned orchestrator reply after
    /// a short artificial delay, so the streaming/busy state is honestly
    /// exercised. Throws `SendChatMessageError` on failure.
    func send(_ text: String, to target: ConversationTarget) async throws

    /// The live transcript, chronologically ordered.
    func observeTranscript() -> AsyncStream<[ChatMessage]>

    /// The live context-usage fraction, clamped to 0...1.
    func observeContextUsage() -> AsyncStream<ConversationContextUsage>

    /// Whether a response is currently streaming. While true, new sends and
    /// resets must be rejected.
    var isStreaming: Bool { get }

    /// Clears the conversation. Throws `ResetConversationError` on failure.
    func resetConversation() async throws

    /// Fetches the orchestrator's dynamic UI card history.
    /// Throws `DynamicUICardHistoryError` on failure.
    func fetchDynamicUICardHistory() async throws -> [DynamicUICard]

    /// Removes one dynamic UI card, both from history and (if still shown)
    /// live — the real backend persists cards server-side (`GET /api/cards`
    /// restores them after a reload), so a dismissal has to round-trip, not
    /// just update local UI state.
    func removeDynamicUICard(id: String) async throws

    /// Cancels the in-flight turn. Throws `CancelConversationError` on
    /// failure. History is kept — this only stops the reply, it doesn't
    /// undo anything already said or done.
    func cancelCurrentTurn() async throws

    /// Fires (no payload — just a "a new one arrived" pulse) whenever the
    /// orchestrator creates or updates a dynamic UI card, so the Chat
    /// screen can show a notification dot on the card-browser entry point
    /// without needing to have fetched the full history first.
    func observeDynamicUICardUpdates() -> AsyncStream<Void>
}
