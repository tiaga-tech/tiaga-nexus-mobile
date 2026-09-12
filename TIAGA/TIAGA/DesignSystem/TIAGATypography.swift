//
//  TIAGATypography.swift
//  TIAGA
//

import SwiftUI

/// The app's type scale. Every `Text` must use one of these — never a raw
/// `.font(.system(size:))` literal in a View. All tokens are built on top of
/// Dynamic Type text styles so they scale with the operator's chosen text size.
enum TIAGATypography {

    /// Screen titles (e.g. "Fleet", "Agents").
    static let screenTitle = Font.system(.title, design: .default, weight: .bold)

    /// The "TIAGA" wordmark itself — Login and any other brand/splash moment.
    /// Deliberately a step above `screenTitle`: this is the one place the
    /// product's own name is the content, not a navigation label.
    static let wordmark = Font.system(.largeTitle, design: .default, weight: .heavy)

    /// Card/row titles (a device name, an agent's name).
    static let headline = Font.system(.headline, design: .default, weight: .semibold)

    /// Primary reading text.
    static let body = Font.system(.body, design: .default, weight: .regular)

    /// Secondary/supporting text (timestamps, device type, last-seen).
    static let subheadline = Font.system(.subheadline, design: .default, weight: .regular)

    /// A name emphasized inline within otherwise-secondary text at the same
    /// size — e.g. the requester/device name in "TIAGA on Mac wants to run
    /// a command" (matches the web client's `font-medium` spans in
    /// `PermissionOverlay.tsx`, which are the same size as the surrounding
    /// text, just bolder).
    static let subheadlineEmphasis = Font.system(.subheadline, design: .default, weight: .semibold)

    /// Small metadata (status pill labels, badge counts).
    static let caption = Font.system(.caption, design: .default, weight: .medium)

    /// The exact shell command or diff shown on a permission approval card —
    /// monospaced so an operator can read it precisely before approving.
    static let command = Font.system(.body, design: .monospaced, weight: .regular)

    /// A file path label or per-file tab — monospaced like `command`, but at
    /// caption size since it's metadata about the code, not the code itself.
    static let commandCaption = Font.system(.caption, design: .monospaced, weight: .regular)
}
