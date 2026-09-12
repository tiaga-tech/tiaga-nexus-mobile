//
//  RemoteDeviceFleetRepository.swift
//  TIAGA
//

import Foundation

/// Talks to the real backend's `DevicesController` (`GET`/`PUT /api/devices`).
/// See AGENTS.md's "Live backend" policy — this is what `DevicesViewModel`
/// runs against outside Xcode Previews.
///
/// One-shot REST only, matching `ObserveDeviceFleetUseCase`'s current shape
/// (a single snapshot fetch, not an ongoing subscription) — the real
/// backend also pushes device presence over its shared `/api/events` SSE
/// stream (`DeviceManager.cs`'s `Describe`, the same payload shape as this
/// list endpoint), but nothing in this app's Devices screen consumes a live
/// stream yet, so wiring that here would be speculative. Revisit if/when
/// `DevicesViewModel` grows a live-updating list.
final class RemoteDeviceFleetRepository: DeviceFleetRepository {
    private let apiClient: TIAGAAPIClient
    private let eventBus: RemoteEventBus

    init(apiClient: TIAGAAPIClient = TIAGAAPIClient(), eventBus: RemoteEventBus = .shared) {
        self.apiClient = apiClient
        self.eventBus = eventBus
    }

    func listDevices() async throws -> [Device] {
        let response: DevicesListPayload = try await apiClient.get("devices")
        return try response.devices.map { try $0.toDevice() }
    }

    /// A pulse per `type: "device"` SSE frame — matches the real payload
    /// shared by the REST list and the live event (`DeviceManager.cs`'s
    /// `DescribeInternal`), but this repository only uses the event as a
    /// signal to re-fetch (see the protocol's doc comment for why).
    func observeDeviceChanges() -> AsyncStream<Void> {
        let upstream = eventBus.events(ofType: "device")
        return AsyncStream { continuation in
            let task = Task {
                for await _ in upstream {
                    continuation.yield(())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func setPermissionsRequired(_ permissionsRequired: Bool, for id: DeviceIdentifier) async throws {
        let _: DevicePayload = try await apiClient.put(
            "devices/\(id.rawValue)",
            body: DeviceUpdateBody(name: nil, type: nil, permissionsRequired: permissionsRequired)
        )
    }
}

/// `GET /api/devices`'s response shape (`DevicesController.List`) — `limit`
/// (the plan's concurrent-connection cap) has no concept in this app yet,
/// so it's decoded and discarded.
private struct DevicesListPayload: Decodable {
    let limit: Int
    let devices: [DevicePayload]
}

/// Shared wire shape for a device — identical whether it comes from the
/// REST list or an SSE event (`DeviceManager.cs`'s `DescribeInternal`).
/// Several fields (`version`, `updating`, `updateAvailable`, ...) exist on
/// the wire but have no equivalent in this app's `Device` model — auto-
/// update isn't a feature here, so they're decoded and discarded too.
private struct DevicePayload: Decodable {
    let id: String
    let name: String
    let deviceType: String
    let online: Bool
    let permissionsRequired: Bool

    func toDevice() throws -> Device {
        guard let type = DeviceType(rawValue: deviceType) else {
            throw APITransportError.decodingFailed
        }
        return Device(
            id: DeviceIdentifier(rawValue: id),
            name: name,
            type: type,
            isOnline: online,
            permissionsRequired: permissionsRequired
        )
    }
}

private struct DeviceUpdateBody: Encodable {
    let name: String?
    let type: String?
    let permissionsRequired: Bool?
}
