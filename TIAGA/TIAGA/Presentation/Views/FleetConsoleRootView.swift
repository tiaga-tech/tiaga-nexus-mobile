//
//  FleetConsoleRootView.swift
//  TIAGA
//

import SwiftUI

/// Whether the side menu's swipe-to-open drag is actively in progress.
/// A human swipe is never perfectly horizontal, so content underneath the
/// drawer (e.g. Chat's transcript `ScrollView`) needs to disable its own
/// scrolling for the duration of that drag — otherwise the same touch
/// simultaneously opens the drawer *and* nudges the scroll position, since
/// `.simultaneousGesture` deliberately lets both recognize at once. Read
/// this via `@Environment(\.isSideMenuOpenGestureActive)` and apply
/// `.scrollDisabled(_:)` wherever a route has its own scrollable content.
private struct SideMenuOpenGestureActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isSideMenuOpenGestureActive: Bool {
        get { self[SideMenuOpenGestureActiveKey.self] }
        set { self[SideMenuOpenGestureActiveKey.self] = newValue }
    }
}

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
    /// True from the moment the open-drawer drag first commits to being
    /// horizontal-dominant until the finger lifts. See both usages below —
    /// it disables underlying scroll content for the duration, and lets the
    /// drag keep tracking (and always resolve to open-or-snap-closed on
    /// release) even if the finger's motion later dips back toward vertical,
    /// e.g. a fast reversal mid-swipe.
    @State private var isOpeningDrag = false

    private let sideMenuWidth: CGFloat = 300
    /// Dragging past this fraction of the drawer's width completes the
    /// open/close gesture instead of snapping back to where it started.
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
            .environment(\.isSideMenuOpenGestureActive, isOpeningDrag)
            // Swipe-to-open from anywhere on the content, not just an edge
            // strip. `.simultaneousGesture` (not `.gesture`) is essential
            // here — a plain `.gesture` on a view this large would claim
            // every touch exclusively and block taps on the hamburger
            // button and any future interactive content underneath it;
            // `.simultaneousGesture` lets this recognize alongside normal
            // taps instead of competing with them. The horizontal-dominant
            // check additionally keeps it from ever hijacking a future
            // vertical scroll (e.g. Chat's message list) — it only tracks
            // once a drag is clearly more sideways than up/down.
            //
            // That dominance check only gates *starting* the drag, though —
            // once `isOpeningDrag` is true, later events keep tracking the
            // finger regardless of its instantaneous ratio, and `onEnded`
            // always resolves to fully open or snapped closed rather than
            // re-checking dominance against the gesture's final translation.
            // Re-checking there was the bug: a fast reversal mid-swipe (open,
            // then flick back left faster than the drawer) could end with a
            // final translation that's no longer horizontal-dominant, so the
            // old guard silently returned — leaving the drawer stuck at
            // whatever offset it was at, with no animation to resolve it.
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard !isSideMenuOpen,
                              isOpeningDrag || abs(value.translation.width) > abs(value.translation.height)
                        else { return }
                        isOpeningDrag = true
                        dragTranslation = max(0, value.translation.width)
                    }
                    .onEnded { value in
                        let wasOpening = isOpeningDrag
                        isOpeningDrag = false
                        guard !isSideMenuOpen, wasOpening else { return }
                        if dragTranslation > sideMenuWidth * dismissDragFraction {
                            openMenu()
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) { dragTranslation = 0 }
                        }
                    }
            )

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
                // The drawer's close DragGesture lives on `SideMenuView`, so
                // it never sees touches that begin outside the panel. The
                // scrim covers that area, so mirror the same leftward
                // drag-to-close here. `simultaneousGesture` keeps the tap
                // gesture above recognized alongside the drag.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            guard isSideMenuOpen else { return }
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
            ChatView()
        case .agentChat(let agentID):
            PlaceholderDetailView(title: "Agent Chat", subtitle: agentID.rawValue)
        case .devices:
            PlaceholderDetailView(title: "Devices")
        case .settings:
            SettingsPlaceholderView(account: account, authViewModel: authViewModel)
        }
    }

    private func openMenu() {
        // Same class of bug already fixed in closeMenu(): resetting
        // dragTranslation *outside* the animated block means it applies
        // instantly, snapping the drawer back to fully closed before the
        // open animation even starts — instead of continuing smoothly from
        // wherever the finger released. Both must change in the same
        // transaction so SwiftUI interpolates from the drawer's actual
        // current position, not from closed.
        withAnimation(.easeInOut(duration: 0.25)) {
            isSideMenuOpen = true
            dragTranslation = 0
        }
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
