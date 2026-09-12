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

    /// Fires (with no payload — just a "something changed, re-fetch" pulse)
    /// whenever the fleet changes elsewhere: another client toggling a
    /// device's permissions, a device connecting/disconnecting, etc. A
    /// pulse-only signal rather than a full live-merged snapshot stream
    /// (like `PermissionRequestRepository.observePendingRequests()`) is a
    /// deliberate simplification — devices change far less often than
    /// permission requests, so re-running the already-tested `listDevices()`
    /// fetch on each pulse is simpler and safer than replicating the web
    /// client's per-action (`online`/`offline`/`renamed`/`removed`/
    /// `updating`) merge logic (`useDevices.ts`) for a rare event. Revisit
    /// if that fetch-per-pulse cost ever actually matters.
    func observeDeviceChanges() -> AsyncStream<Void>

    /// Sets whether sensitive tools on this device require operator approval.
    /// Callers go through `ToggleDevicePermissionsUseCase`.
    func setPermissionsRequired(_ permissionsRequired: Bool, for id: DeviceIdentifier) async throws
}
