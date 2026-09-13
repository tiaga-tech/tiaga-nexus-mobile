//
//  SideMenuViewModel.swift
//  TIAGA
//

import Combine
import Foundation
import SwiftUI

/// Drives the side menu's agent list.
///
/// Owned by `FleetConsoleRootView`, not `SideMenuView` — the roster must
/// start loading as soon as the fleet console appears, not lazily when the
/// drawer is first opened. Loading lazily meant the agent rows were still
/// empty when the drawer's opening animation began, so they popped in a
/// moment later as an unrelated, unanimated state change instead of sliding
/// in with everything else — and reloading every time the drawer reopened
/// meant briefly replacing an already-correct list with a loading spinner.
@MainActor
final class SideMenuViewModel: ObservableObject {
    @Published private(set) var agents: [Agent] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let listAgentRosterUseCase: ListAgentRosterUseCase
    private let repository: AgentRosterRepository

    init(repository: AgentRosterRepository = FakeAgentRosterRepository()) {
        self.repository = repository
        self.listAgentRosterUseCase = ListAgentRosterUseCase(repository: repository)
        startObservingLiveChanges()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await listAgentRosterUseCase.execute()
            withAnimation(.easeInOut(duration: 0.2)) {
                agents = result
            }
        } catch let error as AgentRosterError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = AgentRosterError.fleetUnreachable.errorDescription
        }
    }

    /// Re-fetches on any live roster change (another client, or the
    /// orchestrator dispatching/renaming a task) — without this, the menu
    /// was a one-shot snapshot from when the fleet console first appeared,
    /// only ever refreshed by this same screen's own cancel/delete actions.
    private func startObservingLiveChanges() {
        let rosterChangeStream = repository.observeRosterChanges()
        Task { [weak self] in
            for await _ in rosterChangeStream {
                await self?.load()
            }
        }
    }
}
