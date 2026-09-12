//
//  ObserveDeviceFleetUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

private func makeDevice(name: String, isOnline: Bool) -> Device {
    Device(
        id: DeviceIdentifier(rawValue: name),
        name: name,
        type: .mac,
        isOnline: isOnline,
        permissionsRequired: false
    )
}

private final class StubDeviceFleetRepository: DeviceFleetRepository {
    var devices: [Device] = []
    var shouldFail = false

    func listDevices() async throws -> [Device] {
        if shouldFail { throw DeviceFleetError.fleetUnreachable }
        return devices
    }

    // Not exercised by this use case — trivial conformance only.
    func setPermissionsRequired(_ permissionsRequired: Bool, for id: DeviceIdentifier) async throws {}
}

struct ObserveDeviceFleetUseCaseTests {

    @Test func test_observeDeviceFleet_sortsOnlineBeforeOffline() async throws {
        let repository = StubDeviceFleetRepository()
        repository.devices = [
            makeDevice(name: "Offline Server", isOnline: false),
            makeDevice(name: "Online Laptop", isOnline: true),
        ]
        let useCase = ObserveDeviceFleetUseCase(repository: repository)

        let result = try await useCase.execute()

        #expect(result.map(\.name) == ["Online Laptop", "Offline Server"])
    }

    @Test func test_observeDeviceFleet_breaksTiesAlphabetically() async throws {
        // Boundary: both devices share the same online status, so the sort
        // must fall through to the alphabetical tiebreak rather than leaving
        // the order undefined.
        let repository = StubDeviceFleetRepository()
        repository.devices = [
            makeDevice(name: "Zeta", isOnline: true),
            makeDevice(name: "Alpha", isOnline: true),
        ]
        let useCase = ObserveDeviceFleetUseCase(repository: repository)

        let result = try await useCase.execute()

        #expect(result.map(\.name) == ["Alpha", "Zeta"])
    }

    @Test func test_observeDeviceFleet_fails_whenFleetIsUnreachable() async throws {
        let repository = StubDeviceFleetRepository()
        repository.shouldFail = true
        let useCase = ObserveDeviceFleetUseCase(repository: repository)

        await #expect(throws: DeviceFleetError.fleetUnreachable) {
            _ = try await useCase.execute()
        }
    }
}
