//
//  ChatViewModel.swift
//  TIAGA
//

import Combine
import Foundation
import SwiftUI

/// Drives the main orchestrator Chat screen: the merged transcript, busy state,
/// context usage, send/reset, and dynamic-card history.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var transcript: [ChatMessage] = []
    @Published private(set) var contextUsage = ConversationContextUsage(fraction: 0)
    @Published private(set) var isStreaming = false
    @Published private(set) var sendErrorMessage: String?
    @Published private(set) var resetErrorMessage: String?
    @Published private(set) var dynamicCardHistory: [DynamicUICard] = []
    @Published private(set) var dynamicCardHistoryErrorMessage: String?

    /// User-entered composer text. Kept on the VM so the DEBUG route override
    /// can seed a realistic populated state for screenshots.
    @Published var composerText = ""
    /// Bumped every time `send()` clears the composer — `ChatView` applies
    /// it as the composer's `.id()`. `TextField(axis: .vertical)` has a
    /// known quirk where clearing the bound string alone doesn't always
    /// reset the underlying multi-line text view (observed: the old text
    /// stayed visible after sending). Forcing a fresh view identity on
    /// every send is a blunt but reliable fix, synchronous with the clear
    /// itself rather than waiting on the transcript to update.
    @Published private(set) var composerResetToken = 0

    private let sendUseCase: SendChatMessageUseCase
    private let resetUseCase: ResetConversationUseCase
    private let loadDynamicUICardHistoryUseCase: LoadDynamicUICardHistoryUseCase
    private let removeDynamicUICardUseCase: RemoveDynamicUICardUseCase
    private let repository: OrchestratorConversationRepository

    init(repository: OrchestratorConversationRepository? = nil) {
        // Fake*Repository only inside Xcode Previews — everywhere else
        // (Simulator or a real device) talks to the real backend. See
        // AGENTS.md's "Live backend" policy.
        let resolvedRepository = repository ?? (
            ProcessInfo.isRunningInXcodePreview ? FakeOrchestratorConversationRepository() : RemoteOrchestratorConversationRepository()
        )
        self.repository = resolvedRepository
        self.sendUseCase = SendChatMessageUseCase(orchestratorRepository: resolvedRepository)
        self.resetUseCase = ResetConversationUseCase(repository: resolvedRepository)
        self.loadDynamicUICardHistoryUseCase = LoadDynamicUICardHistoryUseCase(repository: resolvedRepository)
        self.removeDynamicUICardUseCase = RemoveDynamicUICardUseCase(repository: resolvedRepository)
        startObserving()
    }

    func send() async {
        guard !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        sendErrorMessage = nil
        do {
            let text = composerText
            composerText = ""
            composerResetToken += 1
            try await sendUseCase.execute(text: text, to: .orchestrator)
        } catch let error as SendChatMessageError {
            sendErrorMessage = error.errorDescription
        } catch {
            sendErrorMessage = SendChatMessageError.conversationBusy.errorDescription
        }
    }

    func reset() async {
        resetErrorMessage = nil
        do {
            try await resetUseCase.execute()
        } catch let error as ResetConversationError {
            resetErrorMessage = error.errorDescription
        } catch {
            resetErrorMessage = ResetConversationError.conversationBusy.errorDescription
        }
    }

    func loadDynamicCardHistory() async {
        dynamicCardHistoryErrorMessage = nil
        do {
            dynamicCardHistory = try await loadDynamicUICardHistoryUseCase.execute()
        } catch let error as DynamicUICardHistoryError {
            dynamicCardHistoryErrorMessage = error.errorDescription
        } catch {
            dynamicCardHistoryErrorMessage = DynamicUICardHistoryError.unavailable.errorDescription
        }
    }

    /// Removes one dynamic UI card from the operator's current history.
    /// Removed from local state immediately (an operator closing a card
    /// wants it gone now, not after a round-trip), with the backend call
    /// fired alongside — the real backend persists cards server-side
    /// (`GET /api/cards` restores them after a reload), so this has to
    /// actually reach it, not just update local UI state. A failure here
    /// is low-stakes (the card just might reappear next reload) and isn't
    /// surfaced as an error for that reason.
    func dismissDynamicCard(id: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            dynamicCardHistory.removeAll { $0.id == id }
        }
        Task { try? await removeDynamicUICardUseCase.execute(id: id) }
    }

    #if DEBUG
    /// Reads `TIAGA_DEBUG_CHAT_SEED` (pass via
    /// `SIMCTL_CHILD_TIAGA_DEBUG_CHAT_SEED` to `xcrun simctl launch`) so a
    /// screenshot pass can show a populated transcript without real taps or
    /// waiting for the fake's streaming delay.
    static func debugSeedRequested() -> Bool {
        ProcessInfo.processInfo.environment["TIAGA_DEBUG_CHAT_SEED"] == "populated"
    }
    #endif

    private func startObserving() {
        let transcriptStream = repository.observeTranscript()
        let usageStream = repository.observeContextUsage()

        Task { [weak self] in
            for await entries in transcriptStream {
                guard let self else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.transcript = entries
                }
                self.isStreaming = self.repository.isStreaming
            }
        }

        Task { [weak self] in
            for await usage in usageStream {
                self?.contextUsage = usage
            }
        }
    }
}
