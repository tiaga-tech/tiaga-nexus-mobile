//
//  DevicePermissionsError.swift
//  TIAGA
//

import Foundation

/// Failure states from `ToggleDevicePermissionsUseCase`. Encountered by an
/// operator switching a device's approval-gating on/off from the Devices
/// screen.
enum DevicePermissionsError: Error, Equatable, LocalizedError {
    /// The device no longer exists — it may have disconnected and been
    /// removed between opening the screen and toggling it.
    case deviceNoLongerExists

    var errorDescription: String? {
        switch self {
        case .deviceNoLongerExists:
            return "This device no longer exists — it may have been removed."
        }
    }
}
