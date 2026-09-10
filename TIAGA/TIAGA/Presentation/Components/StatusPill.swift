//
//  StatusPill.swift
//  TIAGA
//

import SwiftUI

/// A small tinted label used to show an agent's state or a device's online
/// presence at a glance. Matches the real product's own status-badge style
/// (a low-opacity fill of the status color, with matching text and dot) —
/// color always comes from a domain-state mapping, never a raw color.
struct StatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: TIAGASpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: TIAGASpacing.xs, height: TIAGASpacing.xs)
            Text(label)
                .font(TIAGATypography.caption)
                .foregroundStyle(color)
        }
        .padding(.horizontal, TIAGASpacing.sm)
        .padding(.vertical, TIAGASpacing.xs)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

extension StatusPill {
    init(agentState: AgentState) {
        let label: String
        switch agentState {
        case .idle: label = "Idle"
        case .running: label = "Running"
        case .compacting: label = "Compacting"
        case .error: label = "Error"
        }
        self.init(label: label, color: TIAGAColor.forAgentState(agentState))
    }

    init(isOnline: Bool) {
        self.init(
            label: isOnline ? "Online" : "Offline",
            color: TIAGAColor.forDevicePresence(isOnline: isOnline)
        )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: TIAGASpacing.sm) {
        StatusPill(agentState: .running)
        StatusPill(agentState: .compacting)
        StatusPill(agentState: .error(reason: "Build failed"))
        StatusPill(isOnline: true)
        StatusPill(isOnline: false)
    }
    .padding()
    .background(TIAGAColor.background)
}
