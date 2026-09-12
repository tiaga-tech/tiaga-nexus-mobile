//
//  FakePermissionRequestRepository.swift
//  TIAGA
//

import Foundation

/// Fixture-backed `PermissionRequestRepository` — plain Swift values held in
/// memory, no network calls, ever. See CLAUDE.md's "Live backend" policy.
/// Approve/deny only ever mutate this in-memory fixture — no real command is
/// ever authorized to run anywhere.
final class FakePermissionRequestRepository: PermissionRequestRepository, @unchecked Sendable {

    private let lock = NSLock()
    private var pendingByID: [String: PermissionRequest]
    private var pendingOrder: [String]
    private var continuations: [UUID: AsyncStream<[PermissionRequest]>.Continuation] = [:]

    init() {
        let fixtureRequests = [
            PermissionRequest(
                id: "permission-1",
                deviceID: DeviceIdentifier(rawValue: "device-work-laptop"),
                deviceName: "Work Laptop",
                requester: "Comet",
                tool: "bash",
                kind: .command,
                file: nil,
                detail: "npm run build",
                files: nil
            ),
            PermissionRequest(
                id: "permission-2",
                deviceID: DeviceIdentifier(rawValue: "device-server"),
                deviceName: "Build Server",
                requester: "TIAGA",
                tool: "edit",
                kind: .edit,
                file: "web/src/App.tsx",
                detail: "- const title = 'Old'\n+ const title = 'New'",
                files: [
                    PermissionRequestFile(
                        path: "web/src/App.tsx",
                        edits: [PermissionRequestEdit(old: "const title = 'Old'", new: "const title = 'New'")]
                    ),
                ]
            ),
        ]
        pendingOrder = fixtureRequests.map(\.id)
        pendingByID = Dictionary(uniqueKeysWithValues: fixtureRequests.map { ($0.id, $0) })
    }

    func observePendingRequests() -> AsyncStream<[PermissionRequest]> {
        AsyncStream { continuation in
            let subscriptionID = UUID()
            lock.withLock { continuations[subscriptionID] = continuation }
            continuation.yield(snapshot())

            let keepAlive = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                }
                _ = self
            }
            continuation.onTermination = { [weak self] _ in
                keepAlive.cancel()
                self?.removeContinuation(subscriptionID)
            }
        }
    }

    func approve(_ id: String) async throws {
        try resolve(id)
    }

    func deny(_ id: String) async throws {
        try resolve(id)
    }

    private func resolve(_ id: String) throws {
        guard lock.withLock({ pendingByID[id] }) != nil else {
            throw PermissionRequestError.requestAlreadyResolved
        }
        lock.withLock {
            pendingByID[id] = nil
            pendingOrder.removeAll { $0 == id }
        }
        publish()
    }

    private func snapshot() -> [PermissionRequest] {
        lock.withLock { pendingOrder.compactMap { pendingByID[$0] } }
    }

    private func publish() {
        let snapshot = snapshot()
        let activeContinuations = lock.withLock { Array(continuations.values) }
        for continuation in activeContinuations {
            continuation.yield(snapshot)
        }
    }

    private func removeContinuation(_ id: UUID) {
        lock.withLock { continuations[id] = nil }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
