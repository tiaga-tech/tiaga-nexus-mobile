//
//  ToggleDevicePermissionsUseCase.swift
//  TIAGA
//

import Foundation

/// Switches whether a device's sensitive tools require operator approval,
/// backing the Devices screen's permissions toggle.
///
/// Section 8 (Permissions) checked `DeviceManager.cs` directly: toggling is
/// unconditional on the real product, with no guard against pending
/// permission requests. The business rule this doc comment used to plan for
/// ("can't disable while requests are pending") turned out not to exist —
/// left here so a future session doesn't reintroduce it from the same
/// original (unverified) assumption.
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
