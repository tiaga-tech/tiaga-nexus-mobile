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

    /// Card/row titles (a device name, an agent's name).
    static let headline = Font.system(.headline, design: .default, weight: .semibold)

    /// Primary reading text.
    static let body = Font.system(.body, design: .default, weight: .regular)

    /// Secondary/supporting text (timestamps, device type, last-seen).
    static let subheadline = Font.system(.subheadline, design: .default, weight: .regular)

    /// Small metadata (status pill labels, badge counts).
    static let caption = Font.system(.caption, design: .default, weight: .medium)

    /// The exact shell command or diff shown on a permission approval card —
    /// monospaced so an operator can read it precisely before approving.
    static let command = Font.system(.body, design: .monospaced, weight: .regular)
}
