//
//  AgentConversationRepository.swift
//  TIAGA
//

import Foundation

/// One pinned agent's own direct conversation — separate from the
/// orchestrator's conversation (`OrchestratorConversationRepository`), since
/// an agent "has its own chat history" as its own domain concept (see
/// CLAUDE.md's `Agent` noun). Protocol only — see
/// `Data/Repositories/FakeAgentConversationRepository.swift` for the
/// (fixture-backed, no-network) implementation. Never call this directly
/// from a View; go through `SendChatMessageUseCase`.
protocol AgentConversationRepository {
    /// Adds an operator message to `agentID`'s conversation and produces a
    /// canned acknowledgment after a short artificial delay, mirroring the
    /// orchestrator conversation's honest busy-state exercise.
    func send(_ text: String, to agentID: AgentIdentifier) async throws

    /// The live transcript for one agent's conversation (messages + tool
    /// usage merged chronologically).
    func observeTranscript(for agentID: AgentIdentifier) -> AsyncStream<[TranscriptEntry]>
}
