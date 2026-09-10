//
//  SideMenuView.swift
//  TIAGA
//

import SwiftUI

/// The fleet console's navigation drawer content. "Chat" is fixed and always
/// first, then the operator's agents (name + state), then Devices and
/// Settings — all using the same `SideMenuRow` styling.
struct SideMenuView: View {
    @ObservedObject var viewModel: SideMenuViewModel
    let selectedRoute: AppRoute
    let onSelectRoute: (AppRoute) -> Void
    let onClose: () -> Void

    var body: some View {
        // Liquid Glass is a material for floating controls, not backgrounds —
        // wrapping the whole panel in .glassEffect() merged every row's own
        // glass into one giant flat surface, which is why only the (system-
        // provided, real toolbar) hamburger button looked properly "native"
        // and everything else looked flat at rest. The panel itself is a
        // plain surface; GlassEffectContainer here just lets the individual
        // row buttons blend/merge correctly with each other, not with a
        // background shape.
        GlassEffectContainer {
            menuContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Solid, not translucent: Liquid Glass buttons need a plain backdrop
        // to refract against — a translucent panel background here would
        // just be showing through to the dimming scrim behind it, not glass.
        .background(TIAGAColor.background)
        .task { await viewModel.load() }
    }

    private var menuContent: some View {
        VStack(alignment: .leading, spacing: TIAGASpacing.sm) {
            HStack {
                Text("TIAGA")
                    .font(TIAGATypography.wordmark)
                    .foregroundStyle(TIAGAColor.textPrimary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: TIAGAIcon.close)
                        .foregroundStyle(TIAGAColor.textSecondary)
                        // A glass button needs an explicit frame to read as
                        // a proper standalone shape (with the same shimmer/
                        // edge-highlight quality as the row buttons) instead
                        // of a flat tinted circle sized to just the glyph.
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            .padding(.bottom, TIAGASpacing.lg)

            SideMenuRow(icon: TIAGAIcon.menuChat, title: "Chat", isSelected: selectedRoute == .chat) {
                onSelectRoute(.chat)
            }

            Text("AGENTS")
                .font(TIAGATypography.caption)
                .foregroundStyle(TIAGAColor.textTertiary)
                .padding(.top, TIAGASpacing.md)
                .padding(.horizontal, TIAGASpacing.md)

            if viewModel.isLoading {
                ProgressView()
                    .tint(TIAGAColor.brandAccent)
                    .padding(.horizontal, TIAGASpacing.md)
            } else if let message = viewModel.errorMessage {
                Text(message)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.statusDanger)
                    .padding(.horizontal, TIAGASpacing.md)
            } else {
                ForEach(viewModel.agents) { agent in
                    SideMenuRow(
                        icon: nil,
                        title: agent.name,
                        isSelected: selectedRoute == .agentChat(agent.id),
                        accessory: { StatusPill(agentState: agent.state) }
                    ) {
                        onSelectRoute(.agentChat(agent.id))
                    }
                }
            }

            Spacer()

            SideMenuRow(icon: TIAGAIcon.menuDevices, title: "Devices", isSelected: selectedRoute == .devices) {
                onSelectRoute(.devices)
            }
            SideMenuRow(icon: TIAGAIcon.menuSettings, title: "Settings", isSelected: selectedRoute == .settings) {
                onSelectRoute(.settings)
            }
        }
        .padding(TIAGASpacing.lg)
    }
}

#Preview {
    SideMenuView(
        viewModel: SideMenuViewModel(),
        selectedRoute: .chat,
        onSelectRoute: { _ in },
        onClose: {}
    )
    .frame(width: 300)
    .background(TIAGAColor.background)
}
