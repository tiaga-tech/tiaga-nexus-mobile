//
//  ProcessInfo+XcodePreview.swift
//  TIAGA
//

import Foundation

extension ProcessInfo {
    /// True only inside Xcode's canvas, never in a real Simulator/device run
    /// (including a DEBUG build launched normally). Xcode sets this
    /// environment variable specifically for `#Preview` rendering — it's the
    /// standard way to gate preview-only affordances (e.g. fixture-fill
    /// buttons on `LoginView`) out of the actual running app.
    static var isRunningInXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
