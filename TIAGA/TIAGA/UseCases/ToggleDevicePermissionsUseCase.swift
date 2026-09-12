//
//  ToggleDevicePermissionsUseCase.swift
//  TIAGA
//

import Foundation

/// Switches whether a device's sensitive tools require operator approval,
/// backing the Devices screen's permissions toggle.
///
/// Section 8 (Permissions) extends this with a business rule: a device with
/// unresolved pending permission requests can't have approval-gating turned
/// off out from under them. No such rule exists yet — `PermissionRequest`
/// isn't built until that section.
struct ToggleDevicePermissionsUseCase {
    let repository: DeviceFleetRepository

    func execute(deviceID: DeviceIdentifier, permissionsRequired: Bool) async throws {
        let devices = try await repository.listDevices()
        guard devices.contains(where: { $0.id == deviceID }) else {
            throw DevicePermissionsError.deviceNoLongerExists
        }

        try await repository.setPermissionsRequired(permissionsRequired, for: deviceID)
    }
}
