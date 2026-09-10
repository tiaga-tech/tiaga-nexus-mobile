//
//  TIAGACard.swift
//  TIAGA
//

import SwiftUI

/// The standard surface container: a device row, an agent row, a message
/// group. Every card-like surface in the app should be built on this rather
/// than a bespoke background/radius/padding combination.
struct TIAGACard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(TIAGASpacing.lg)
            .background(TIAGAColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous))
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
