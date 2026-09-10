//
//  TIAGACard.swift
//  TIAGA
//

import SwiftUI

/// The standard "glass" surface container: a device row, an agent row, the
/// permission approval sheet. Matches the real product's `.glass` CSS class
/// (a blurred, translucent panel with a faint border) using SwiftUI's native
/// Material rather than a flat fill, so it reads as genuine frosted glass.
struct TIAGACard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(TIAGASpacing.lg)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous)
                    .strokeBorder(TIAGAColor.border, lineWidth: 1)
            )
    }
}

#Preview {
    TIAGACard {
        Text("Preview card content")
            .font(TIAGATypography.body)
            .foregroundStyle(TIAGAColor.textPrimary)
    }
    .padding()
    .background(TIAGAColor.background)
}
