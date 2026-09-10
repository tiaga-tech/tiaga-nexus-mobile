//
//  SideMenuView.swift
//  TIAGA
//

import SwiftUI

/// The fleet console's navigation shell. "Chat" is fixed and always first,
/// then the operator's agents (name + state), then Devices and Settings.
struct SideMenuView: View {
    @ObservedObject var viewModel: SideMenuViewModel
    @Binding var selectedRoute: AppRoute?

    var body: some View {
        List(selection: $selectedRoute) {
            Label("Chat", systemImage: TIAGAIcon.menuChat)
                .tag(AppRoute.chat)

            Section("Agents") {
                if viewModel.isLoading {
                    ProgressView()
                        .listRowBackground(TIAGAColor.background)
                } else if let message = viewModel.errorMessage {
                    Text(message)
                        .font(TIAGATypography.caption)
                        .foregroundStyle(TIAGAColor.statusDanger)
                        .listRowBackground(TIAGAColor.background)
                } else {
                    ForEach(viewModel.agents) { agent in
                        HStack {
                            Text(agent.name)
                                .font(TIAGATypography.body)
                                .foregroundStyle(TIAGAColor.textPrimary)
                            Spacer()
                            StatusPill(agentState: agent.state)
                        }
                        .tag(AppRoute.agentChat(agent.id))
                        .listRowBackground(TIAGAColor.background)
                    }
                }
            }

            Label("Devices", systemImage: TIAGAIcon.menuDevices)
                .tag(AppRoute.devices)
            Label("Settings", systemImage: TIAGAIcon.menuSettings)
                .tag(AppRoute.settings)
        }
        .scrollContentBackground(.hidden)
        .background(TIAGAColor.background)
        .navigationTitle("TIAGA")
        .task { await viewModel.load() }
    }
}

#Preview {
    NavigationStack {
        SideMenuView(viewModel: SideMenuViewModel(), selectedRoute: .constant(.chat))
    }
}
