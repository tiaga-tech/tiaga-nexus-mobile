//
//  DeviceFleetError.swift
//  TIAGA
//

import Foundation

/// Failure states from `ObserveDeviceFleetUseCase`. Encountered by an
/// operator opening the Devices screen.
enum DeviceFleetError: Error, Equatable, LocalizedError {
    /// The backend couldn't be reached to list the fleet's devices.
    case fleetUnreachable

    var errorDescription: String? {
        switch self {
        case .fleetUnreachable:
            return "TIAGA couldn't reach your fleet. Check your connection and try again."
        }
    }
}
