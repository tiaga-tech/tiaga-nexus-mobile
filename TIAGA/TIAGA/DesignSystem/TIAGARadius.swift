//
//  TIAGARadius.swift
//  TIAGA
//

import CoreGraphics

/// The app's corner-radius scale. Every `.cornerRadius()` / `RoundedRectangle`
/// must use one of these — never a raw radius literal in a View.
enum TIAGARadius {
    /// 4pt — small controls (chips, badges).
    static let xs: CGFloat = 4
    /// 8pt — inline controls (buttons, text fields).
    static let sm: CGFloat = 8
    /// 12pt — default control radius.
    static let md: CGFloat = 12
    /// 16pt — standard card radius (device cards, agent cards, process rows).
    static let lg: CGFloat = 16
    /// 24pt — large surfaces (sheets, the approval overlay).
    static let xl: CGFloat = 24
    /// Fully rounded — status pills and circular avatars/icons.
    static let pill: CGFloat = 999
}
