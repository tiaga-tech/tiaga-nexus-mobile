//
//  ContextUsageBar.swift
//  TIAGA
//

import SwiftUI

/// A horizontal fill bar showing how full a conversation's context window is.
/// Color always comes from `TIAGAColor.forContextUsage` — never a raw color —
/// so the green→amber→red escalation stays tied to the real compaction thresholds.
struct ContextUsageBar: View {
    /// 0...1. Values outside that range are clamped.
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: TIAGARadius.pill, style: .continuous)
                    .fill(TIAGAColor.surfaceElevated)
                RoundedRectangle(cornerRadius: TIAGARadius.pill, style: .continuous)
                    .fill(TIAGAColor.forContextUsage(percentage: fraction))
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: TIAGASpacing.xs)
    }
}

#Preview {
    VStack(spacing: TIAGASpacing.md) {
        ContextUsageBar(fraction: 0.3)
        ContextUsageBar(fraction: 0.8)
        ContextUsageBar(fraction: 1.0)
    }
    .padding()
    .background(TIAGAColor.background)
}
