//
//  FleetConsoleRootView.swift
//  TIAGA
//

import SwiftUI

/// The fleet console shown to an authenticated `.active` account: the side
/// menu plus a detail pane. Chat, Devices, and Agent Chat are placeholders
/// until their own sections land; Settings' placeholder carries Log Out
/// since that's its real future home (see `LogoutUseCase`'s doc comment).
struct FleetConsoleRootView: View {
    let account: Account
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var sideMenuViewModel = SideMenuViewModel()
    @State private var selectedRoute: AppRoute?

    init(account: Account, authViewModel: AuthViewModel) {
        self.account = account
        self.authViewModel = authViewModel
        #if DEBUG
        if ProcessInfo.processInfo.environment["TIAGA_DEBUG_SELECTED_ROUTE"] == "sideMenu" {
            _selectedRoute = State(initialValue: nil)
        } else {
            _selectedRoute = State(initialValue: Self.debugInitialRoute() ?? .chat)
        }
        #else
        _selectedRoute = State(initialValue: .chat)
        #endif
    }

    var body: some View {
        NavigationSplitView {
            SideMenuView(viewModel: sideMenuViewModel, selectedRoute: $selectedRoute)
        } detail: {
            NavigationStack {
                switch selectedRoute {
                case .chat, .none:
                    PlaceholderDetailView(title: "Chat")
                case .agentChat(let agentID):
                    PlaceholderDetailView(title: "Agent Chat", subtitle: agentID.rawValue)
                case .devices:
                    PlaceholderDetailView(title: "Devices")
                case .settings:
                    SettingsPlaceholderView(account: account, authViewModel: authViewModel)
                }
            }
        }
        .background(TIAGAColor.background)
    }

    #if DEBUG
    /// Screenshot/QA tooling only — lets `xcrun simctl launch` land straight
    /// on a specific detail pane (via SIMCTL_CHILD_TIAGA_DEBUG_SELECTED_ROUTE)
    /// without driving real taps. Never present in a Release build.
    private static func debugInitialRoute() -> AppRoute? {
        switch ProcessInfo.processInfo.environment["TIAGA_DEBUG_SELECTED_ROUTE"] {
        case "chat": return .chat
        case "devices": return .devices
        case "settings": return .settings
        case "agentChat": return .agentChat(AgentIdentifier(rawValue: "agent-atlas"))
        default: return nil
        }
    }
    #endif
}

/// Stand-in for a not-yet-built destination (Chat, Devices, Agent Chat).
private struct PlaceholderDetailView: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: TIAGASpacing.sm) {
            Text(title)
                .font(TIAGATypography.screenTitle)
                .foregroundStyle(TIAGAColor.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(TIAGATypography.subheadline)
                    .foregroundStyle(TIAGAColor.textSecondary)
            }
            Text("Not built yet — coming in a later section.")
                .font(TIAGATypography.caption)
                .foregroundStyle(TIAGAColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TIAGAColor.background)
        .navigationTitle(title)
    }
}

/// Stand-in for the real Settings screen (Section 9) — carries Log Out for
/// now since that's its real future home, so the auth loop stays closeable.
private struct SettingsPlaceholderView: View {
    let account: Account
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: TIAGASpacing.lg) {
            Text("Settings")
                .font(TIAGATypography.screenTitle)
                .foregroundStyle(TIAGAColor.textPrimary)
            Text(account.email)
                .font(TIAGATypography.subheadline)
                .foregroundStyle(TIAGAColor.textSecondary)
            Text("Not built yet — coming in a later section.")
                .font(TIAGATypography.caption)
                .foregroundStyle(TIAGAColor.textTertiary)
            Button("Log Out") {
                Task { await authViewModel.logout() }
            }
            .font(TIAGATypography.body)
            .foregroundStyle(TIAGAColor.brandAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TIAGAColor.background)
        .navigationTitle("Settings")
    }
}
