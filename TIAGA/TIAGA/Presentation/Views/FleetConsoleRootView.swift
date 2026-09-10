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
    /// Non-zero only while the drawer is actively being dragged — an offset
    /// added on top of `restingOffset`, not the drawer's absolute position.
    @State private var dragTranslation: CGFloat = 0

    private let sideMenuWidth: CGFloat = 300
    /// Dragging past this fraction of the drawer's width completes the
    /// open/close gesture instead of snapping back to where it started.
    private let dismissDragFraction: CGFloat = 0.3
    /// A swipe must start within this many points of the left edge to open
    /// the drawer — otherwise every rightward swipe anywhere on the main
    /// content would try to open it.
    private let edgeSwipeActivationWidth: CGFloat = 24

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

    /// The drawer's resting horizontal offset for its current open/closed
    /// intent — 0 when open, fully off-screen to the left when closed.
    private var restingOffset: CGFloat { isSideMenuOpen ? 0 : -sideMenuWidth }

    /// `restingOffset` plus whatever's in progress from an active drag
    /// (either direction), clamped so a drag can never overshoot past fully
    /// open or fully closed.
    private var drawerOffset: CGFloat {
        max(-sideMenuWidth, min(0, restingOffset + dragTranslation))
    }

    /// How open the drawer is right now, 0...1 — driven by `drawerOffset`
    /// rather than the binary `isSideMenuOpen`, so the scrim dims
    /// proportionally while dragging instead of jumping at the very end.
    private var openFraction: Double {
        Double((drawerOffset + sideMenuWidth) / sideMenuWidth)
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

            // An edge-swipe-to-open zone, only while closed — a plain
            // invisible hit area, not Liquid Glass content, so conditional
            // insertion here doesn't hit the transition-animation problem
            // above (nothing about it is ever animated in/out).
            if !isSideMenuOpen {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: edgeSwipeActivationWidth)
                    .frame(maxHeight: .infinity)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragTranslation = max(0, value.translation.width)
                            }
                            .onEnded { value in
                                if value.translation.width > sideMenuWidth * dismissDragFraction {
                                    openMenu()
                                } else {
                                    withAnimation(.easeOut(duration: 0.2)) { dragTranslation = 0 }
                                }
                            }
                    )
            }

            // The scrim and drawer are always in the hierarchy — never
            // conditionally inserted/removed with `if` + `.transition()`.
            // That combination didn't reliably animate on removal (likely
            // GlassEffectContainer's own rendering pass tearing down
            // immediately on removal rather than participating in the
            // transition), so visibility is driven by directly animating
            // opacity/offset instead, which SwiftUI handles far more
            // reliably and is the standard approach for a custom drawer.
            Color.black.opacity(0.35 * openFraction)
                .ignoresSafeArea()
                .allowsHitTesting(isSideMenuOpen)
                .onTapGesture { closeMenu() }

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
            .offset(x: drawerOffset)
            .allowsHitTesting(isSideMenuOpen)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard isSideMenuOpen else { return }
                        // Only lets the drawer drag further closed (leftwards).
                        dragTranslation = min(0, value.translation.width)
                    }
                    .onEnded { value in
                        guard isSideMenuOpen else { return }
                        if value.translation.width < -sideMenuWidth * dismissDragFraction {
                            closeMenu()
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) { dragTranslation = 0 }
                        }
                    }
            )
        }
        .background(TIAGAColor.background)
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
        dragTranslation = 0
        withAnimation(.easeInOut(duration: 0.25)) { isSideMenuOpen = true }
    }

    private func closeMenu() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isSideMenuOpen = false
            dragTranslation = 0
        }
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
