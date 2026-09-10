//
//  FleetConsoleRootView.swift
//  TIAGA
//

import SwiftUI

/// The fleet console shown to an authenticated `.active` account: a
/// hamburger-triggered slide-out drawer (the side menu) over the current
/// screen. Chat, Devices, and Agent Chat are placeholders until their own
/// sections land; Settings' placeholder carries Log Out since that's its
/// real future home (see `LogoutUseCase`'s doc comment).
struct FleetConsoleRootView: View {
    let account: Account
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var sideMenuViewModel = SideMenuViewModel()
    @State private var selectedRoute: AppRoute
    @State private var isSideMenuOpen: Bool
    @State private var dragOffset: CGFloat = 0

    private let sideMenuWidth: CGFloat = 300
    /// Dragging the drawer left past this fraction of its width closes it.
    private let dismissDragFraction: CGFloat = 0.3

    init(account: Account, authViewModel: AuthViewModel) {
        self.account = account
        self.authViewModel = authViewModel
        #if DEBUG
        let rawSelectedRoute = ProcessInfo.processInfo.environment["TIAGA_DEBUG_SELECTED_ROUTE"]
        _isSideMenuOpen = State(initialValue: rawSelectedRoute == "sideMenu")
        _selectedRoute = State(initialValue: Self.debugRoute(from: rawSelectedRoute) ?? .chat)
        #else
        _isSideMenuOpen = State(initialValue: false)
        _selectedRoute = State(initialValue: .chat)
        #endif
    }

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                detailView(for: selectedRoute)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                openMenu()
                            } label: {
                                Image(systemName: TIAGAIcon.sideMenuToggle)
                                    .foregroundStyle(TIAGAColor.textPrimary)
                            }
                        }
                    }
            }
            .disabled(isSideMenuOpen)

            if isSideMenuOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { closeMenu() }
                    .transition(.opacity)

                SideMenuView(
                    viewModel: sideMenuViewModel,
                    selectedRoute: selectedRoute,
                    onSelectRoute: { route in
                        selectedRoute = route
                        closeMenu()
                    },
                    onClose: { closeMenu() }
                )
                .frame(width: sideMenuWidth)
                .frame(maxHeight: .infinity)
                .offset(x: dragOffset)
                .transition(.move(edge: .leading))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = min(0, value.translation.width)
                        }
                        .onEnded { value in
                            if value.translation.width < -sideMenuWidth * dismissDragFraction {
                                closeMenu()
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                            }
                        }
                )
            }
        }
        .background(TIAGAColor.background)
        .animation(.easeInOut(duration: 0.25), value: isSideMenuOpen)
        // Starts as soon as the fleet console appears, not lazily when the
        // drawer is first opened — otherwise the agent rows are still empty
        // when the drawer's opening animation begins and pop in a moment
        // later, unanimated, instead of sliding in with everything else.
        .task { await sideMenuViewModel.load() }
    }

    @ViewBuilder
    private func detailView(for route: AppRoute) -> some View {
        switch route {
        case .chat:
            PlaceholderDetailView(title: "Chat")
        case .agentChat(let agentID):
            PlaceholderDetailView(title: "Agent Chat", subtitle: agentID.rawValue)
        case .devices:
            PlaceholderDetailView(title: "Devices")
        case .settings:
            SettingsPlaceholderView(account: account, authViewModel: authViewModel)
        }
    }

    private func openMenu() {
        dragOffset = 0
        withAnimation(.easeInOut(duration: 0.25)) { isSideMenuOpen = true }
    }

    private func closeMenu() {
        withAnimation(.easeInOut(duration: 0.25)) { isSideMenuOpen = false }
        dragOffset = 0
    }

    #if DEBUG
    /// Screenshot/QA tooling only — lets `xcrun simctl launch` land straight
    /// on a specific screen, or the drawer itself ("sideMenu"), via
    /// SIMCTL_CHILD_TIAGA_DEBUG_SELECTED_ROUTE, without driving real taps.
    /// Never present in a Release build.
    private static func debugRoute(from raw: String?) -> AppRoute? {
        switch raw {
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
        .navigationBarTitleDisplayMode(.inline)
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
        .navigationBarTitleDisplayMode(.inline)
    }
}
