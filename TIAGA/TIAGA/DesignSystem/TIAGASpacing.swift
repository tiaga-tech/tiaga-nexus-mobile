//
//  TIAGASpacing.swift
//  TIAGA
//

import CoreGraphics

/// The app's spacing scale. Every `.padding()`, `VStack(spacing:)`, and manual
/// offset must use one of these — never a raw point literal in a View.
enum TIAGASpacing {
    /// 4pt — tight spacing inside a compact control (e.g. an icon/label pair, a status dot).
    static let xs: CGFloat = 4
    /// 8pt — spacing between closely related elements.
    static let sm: CGFloat = 8
    /// 12pt — default spacing between rows inside a card.
    static let md: CGFloat = 12
    /// 16pt — standard screen margin and default card padding.
    static let lg: CGFloat = 16
    /// 24pt — spacing between distinct sections on a screen.
    static let xl: CGFloat = 24
    /// 32pt — spacing above/below a screen's primary content block.
    static let xxl: CGFloat = 32
    /// 48pt — large separation, e.g. above an empty-state illustration.
    static let xxxl: CGFloat = 48
}
