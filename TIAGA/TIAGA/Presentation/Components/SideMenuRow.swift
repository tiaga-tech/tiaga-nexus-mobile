//
//  SideMenuRow.swift
//  TIAGA
//

import SwiftUI

/// A single tappable row in the side menu — used for "Chat", "Devices",
/// "Settings", and every agent, so they all share one visual treatment
/// instead of agents looking like plain text next to button-styled entries.
struct SideMenuRow<Accessory: View>: View {
    let icon: String?
    let title: String
    let isSelected: Bool
    @ViewBuilder var accessory: () -> Accessory
    let action: () -> Void

    var body: some View {
        // .tint() alone doesn't make a plain `.glass` button look selected —
        // the glass *fill* itself needs the prominent variant, not just a
        // different foreground color, or every row reads as identically
        // highlighted regardless of which screen is actually active.
        Group {
            if isSelected {
                label.buttonStyle(.glassProminent).tint(TIAGAColor.brandAccent)
            } else {
                label.buttonStyle(.glass)
            }
        }
    }

    private var label: some View {
        Button(action: action) {
            HStack(spacing: TIAGASpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(TIAGAColor.textPrimary)
                }
                Text(title)
                    .font(TIAGATypography.body)
                    .foregroundStyle(TIAGAColor.textPrimary)
                Spacer(minLength: TIAGASpacing.sm)
                accessory()
            }
            .padding(.horizontal, TIAGASpacing.md)
            .padding(.vertical, TIAGASpacing.sm)
            // Without an explicit frame, the row is only as wide as its
            // content, so the trailing whitespace next to a short title
            // isn't part of the button's bounds at all.
            .frame(maxWidth: .infinity, alignment: .leading)
            // Without this, only the glyphs (text/icon) are tappable — the
            // whitespace between them and the trailing accessory is not,
            // because HStack's layout bounds aren't automatically its hit area.
            .contentShape(RoundedRectangle(cornerRadius: TIAGARadius.md, style: .continuous))
        }
    }
}

extension SideMenuRow where Accessory == EmptyView {
    init(icon: String?, title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.init(icon: icon, title: title, isSelected: isSelected, accessory: { EmptyView() }, action: action)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
        SideMenuRow(icon: TIAGAIcon.menuChat, title: "Chat", isSelected: true) {}
        SideMenuRow(icon: nil, title: "Atlas", isSelected: false, accessory: { StatusPill(agentState: .running) }) {}
        SideMenuRow(icon: TIAGAIcon.menuSettings, title: "Settings", isSelected: false) {}
    }
    .padding()
    .background(TIAGAColor.background)
}
