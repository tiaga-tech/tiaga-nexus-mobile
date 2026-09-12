//
//  ToggleDevicePermissionsUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

private func makeDevice(id: String, permissionsRequired: Bool) -> Device {
    Device(
        id: DeviceIdentifier(rawValue: id),
        name: id,
        type: .mac,
        isOnline: true,
        permissionsRequired: permissionsRequired
    )
}

/// Thin purpose-built fake for `ToggleDevicePermissionsUseCase` — a single
/// controllable device and a record of what got set.
private final class StubDeviceFleetRepository: DeviceFleetRepository {
    var device: Device?
    private(set) var lastSetValue: Bool?

    func listDevices() async throws -> [Device] {
        device.map { [$0] } ?? []
    }

    func setPermissionsRequired(_ permissionsRequired: Bool, for id: DeviceIdentifier) async throws {
        lastSetValue = permissionsRequired
    }
}

struct ToggleDevicePermissionsUseCaseTests {

    @Test func test_toggleDevicePermissions_enables_whenCurrentlyDisabled() async throws {
        let repository = StubDeviceFleetRepository()
        repository.device = makeDevice(id: "device-1", permissionsRequired: false)
        let useCase = ToggleDevicePermissionsUseCase(repository: repository)

        try await useCase.execute(deviceID: DeviceIdentifier(rawValue: "device-1"), permissionsRequired: true)

        #expect(repository.lastSetValue == true)
    }

    @Test func test_toggleDevicePermissions_disables_whenCurrentlyEnabled() async throws {
        let repository = StubDeviceFleetRepository()
        repository.device = makeDevice(id: "device-1", permissionsRequired: true)
        let useCase = ToggleDevicePermissionsUseCase(repository: repository)

        try await useCase.execute(deviceID: DeviceIdentifier(rawValue: "device-1"), permissionsRequired: false)

        #expect(repository.lastSetValue == false)
    }

    @Test func test_toggleDevicePermissions_fails_whenDeviceNoLongerExists() async throws {
        let repository = StubDeviceFleetRepository()
        repository.device = nil
        let useCase = ToggleDevicePermissionsUseCase(repository: repository)

        await #expect(throws: DevicePermissionsError.deviceNoLongerExists) {
            try await useCase.execute(deviceID: DeviceIdentifier(rawValue: "device-1"), permissionsRequired: true)
        }
        #expect(repository.lastSetValue == nil)
    }
}
