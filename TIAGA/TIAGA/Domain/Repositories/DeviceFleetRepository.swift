//
//  DeviceFleetRepository.swift
//  TIAGA
//

import Foundation

/// The operator's fleet of devices. Protocol only — see
/// `Data/Repositories/FakeDeviceFleetRepository.swift` for the (fixture-
/// backed, no-network) implementation. Never call this directly from a
/// View; go through `ObserveDeviceFleetUseCase`.
protocol DeviceFleetRepository {
    func listDevices() async throws -> [Device]

    /// Sets whether sensitive tools on this device require operator approval.
    /// Callers go through `ToggleDevicePermissionsUseCase`.
    func setPermissionsRequired(_ permissionsRequired: Bool, for id: DeviceIdentifier) async throws
}
