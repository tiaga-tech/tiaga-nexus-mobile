//
//  RemotePermissionRequestRepository.swift
//  TIAGA
//

import Foundation

/// Talks to the real backend's `PermissionsController` (`GET`/`POST
/// /api/permissions`) and its shared `/api/events` SSE stream (via
/// `RemoteEventBus`, `type: "permission"`). See AGENTS.md's "Live backend"
/// policy — this is what `PermissionRequestOverlayViewModel` runs against
/// outside Xcode Previews.
final class RemotePermissionRequestRepository: PermissionRequestRepository {
    private let apiClient: TIAGAAPIClient
    private let eventBus: RemoteEventBus

    init(apiClient: TIAGAAPIClient = TIAGAAPIClient(), eventBus: RemoteEventBus = .shared) {
        self.apiClient = apiClient
        self.eventBus = eventBus
    }

    func observePendingRequests() -> AsyncStream<[PermissionRequest]> {
        AsyncStream { continuation in
            let task = Task {
                // Oldest-first order, matching the overlay's queueing rule —
                // maintained here as `PermissionRequestOverlayViewModel`
                // just takes `requests.first` from whatever this yields.
                var order: [String] = []
                var pendingByID: [String: PermissionRequest] = [:]

                func publish() {
                    continuation.yield(order.compactMap { pendingByID[$0] })
                }

                // Restores any already-pending requests (e.g. one raised
                // before this session connected) — `PermissionsController`'s
                // own doc comment: "so a refreshed page can restore the
                // approval dialog."
                if let snapshot: [PermissionRequestPayload] = try? await apiClient.get("permissions") {
                    let requests = snapshot.compactMap { try? $0.toDomain() }
                    order = requests.map(\.id)
                    pendingByID = Dictionary(uniqueKeysWithValues: requests.map { ($0.id, $0) })
                    publish()
                }

                for await data in self.eventBus.events(ofType: "permission") {
                    guard let envelope = try? JSONDecoder().decode(PermissionEventEnvelope.self, from: data) else { continue }
                    switch envelope.action {
                    case "request":
                        guard let payload = try? JSONDecoder().decode(PermissionRequestPayload.self, from: data),
                              let request = try? payload.toDomain() else { continue }
                        if pendingByID[request.id] == nil {
                            order.append(request.id)
                        }
                        pendingByID[request.id] = request
                        publish()
                    case "resolved":
                        // Resolved by ANY client (this app, the web, or a
                        // timeout/cancellation server-side) — drop it from
                        // our own queue regardless of who acted.
                        guard pendingByID.removeValue(forKey: envelope.id) != nil else { continue }
                        order.removeAll { $0 == envelope.id }
                        publish()
                    default:
                        break
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func approve(_ id: String) async throws {
        try await resolve(id, approved: true)
    }

    func deny(_ id: String) async throws {
        try await resolve(id, approved: false)
    }

    private func resolve(_ id: String, approved: Bool) async throws {
        try await apiClient.postExpectingNoContent("permissions/\(id)/resolve", body: ResolveBody(approved: approved))
    }
}

/// Just enough to route an SSE `type: "permission"` frame — `"request"`
/// (a new pending request; decode the rest with `PermissionRequestPayload`)
/// or `"resolved"` (drop `id` from the pending list; `approved` is who
/// decided it, not needed since either value means "no longer pending").
private struct PermissionEventEnvelope: Decodable {
    let action: String
    let id: String
}

/// Shared wire shape for a pending request — identical whether it comes
/// from `GET /api/permissions` or an SSE `"request"` event
/// (`PermissionManager.cs`'s `AwaitDecisionAsync`/`Pending()`).
private struct PermissionRequestPayload: Decodable {
    let id: String
    let deviceId: String
    let deviceName: String
    let requester: String
    let tool: String
    let kind: String
    let file: String?
    let detail: String
    let files: [PermissionRequestFilePayload]?

    func toDomain() throws -> PermissionRequest {
        guard let kind = PermissionRequestKind(rawValue: kind) else {
            throw APITransportError.decodingFailed
        }
        return PermissionRequest(
            id: id,
            deviceID: DeviceIdentifier(rawValue: deviceId),
            deviceName: deviceName,
            requester: requester,
            tool: tool,
            kind: kind,
            file: file,
            detail: detail,
            files: files?.map { $0.toDomain() }
        )
    }
}

private struct PermissionRequestFilePayload: Decodable {
    let path: String
    let edits: [PermissionRequestEditPayload]

    func toDomain() -> PermissionRequestFile {
        PermissionRequestFile(path: path, edits: edits.map { $0.toDomain() })
    }
}

private struct PermissionRequestEditPayload: Decodable {
    let old: String
    let new: String

    func toDomain() -> PermissionRequestEdit {
        PermissionRequestEdit(old: old, new: new)
    }
}

private struct ResolveBody: Encodable {
    let approved: Bool
}
