//
//  StatusPill.swift
//  TIAGA
//

import SwiftUI

/// A small label + colored dot used to show an agent's state or a device's
/// online presence at a glance. Color always comes from a domain-state
/// mapping (`TIAGAColor.forAgentState`/`forDevicePresence`) — never a raw color.
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
                .foregroundStyle(TIAGAColor.textSecondary)
        }
        .padding(.horizontal, TIAGASpacing.sm)
        .padding(.vertical, TIAGASpacing.xs)
        .background(TIAGAColor.surfaceElevated)
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
