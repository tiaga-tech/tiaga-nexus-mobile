//
//  FakeDeviceFleetRepository.swift
//  TIAGA
//

import Foundation

/// Fixture-backed `DeviceFleetRepository` — plain Swift values held in
/// memory, no network calls, ever. See CLAUDE.md's "Live backend" policy.
final class FakeDeviceFleetRepository: DeviceFleetRepository, @unchecked Sendable {

    /// Set to make `listDevices()` fail, for exercising `.fleetUnreachable`.
    var shouldFail = false

    private let lock = NSLock()
    private var devicesByID: [DeviceIdentifier: Device]
    private var deviceOrder: [DeviceIdentifier]

    init() {
        let fixtureDevices = [
            Device(
                id: DeviceIdentifier(rawValue: "device-home-pc"),
                name: "Home PC",
                type: .windows,
                isOnline: true,
                permissionsRequired: false
            ),
            Device(
                id: DeviceIdentifier(rawValue: "device-work-laptop"),
                name: "Work Laptop",
                type: .mac,
                isOnline: true,
                permissionsRequired: true
            ),
            Device(
                id: DeviceIdentifier(rawValue: "device-server"),
                name: "Build Server",
                type: .linux,
                isOnline: false,
                permissionsRequired: true
            ),
        ]
        deviceOrder = fixtureDevices.map(\.id)
        devicesByID = Dictionary(uniqueKeysWithValues: fixtureDevices.map { ($0.id, $0) })
    }

    func listDevices() async throws -> [Device] {
        if shouldFail {
            throw DeviceFleetError.fleetUnreachable
        }
        return lock.withLock { deviceOrder.compactMap { devicesByID[$0] } }
    }

    /// No live simulation — the fixture is static demo data, and nothing
    /// else in a Preview or a test can mutate the fleet out from under it.
    func observeDeviceChanges() -> AsyncStream<Void> {
        AsyncStream { _ in }
    }

    func setPermissionsRequired(_ permissionsRequired: Bool, for id: DeviceIdentifier) async throws {
        guard let device = lock.withLock({ devicesByID[id] }) else {
            throw DevicePermissionsError.deviceNoLongerExists
        }
        let updated = Device(
            id: device.id,
            name: device.name,
            type: device.type,
            isOnline: device.isOnline,
            permissionsRequired: permissionsRequired
        )
        lock.withLock { devicesByID[id] = updated }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
