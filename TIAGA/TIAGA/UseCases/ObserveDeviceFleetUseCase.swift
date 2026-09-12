//
//  ObserveDeviceFleetUseCase.swift
//  TIAGA
//

import Foundation

/// Lists the operator's devices for the Devices screen.
///
/// Business Rule: online devices sort before offline, then alphabetically
/// within each group — an operator scanning the fleet sees what's reachable
/// right now before what isn't.
struct ObserveDeviceFleetUseCase {
    let repository: DeviceFleetRepository

    func execute() async throws -> [Device] {
        let devices: [Device]
        do {
            devices = try await repository.listDevices()
        } catch {
            throw DeviceFleetError.fleetUnreachable
        }

        return devices.sorted { lhs, rhs in
            if lhs.isOnline != rhs.isOnline {
                return lhs.isOnline && !rhs.isOnline
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
