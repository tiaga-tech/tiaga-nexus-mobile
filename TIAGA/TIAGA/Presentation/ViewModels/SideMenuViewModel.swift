//
//  SideMenuViewModel.swift
//  TIAGA
//

import Combine
import Foundation

/// Drives the side menu's agent list.
@MainActor
final class SideMenuViewModel: ObservableObject {
    @Published private(set) var agents: [Agent] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let listAgentRosterUseCase: ListAgentRosterUseCase

    init(repository: AgentRosterRepository = FakeAgentRosterRepository()) {
        self.listAgentRosterUseCase = ListAgentRosterUseCase(repository: repository)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            agents = try await listAgentRosterUseCase.execute()
        } catch let error as AgentRosterError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = AgentRosterError.fleetUnreachable.errorDescription
        }
    }
}
