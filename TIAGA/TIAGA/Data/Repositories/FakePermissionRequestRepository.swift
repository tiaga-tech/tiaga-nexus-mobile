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
                // The edit tool's real payload is `files: [{ path, edits }]`
                // — more than one file can be edited in a single tool call/
                // permission request. When there's more than one,
                // PermissionManager.cs's DescribeEdit uses "{count} files"
                // as the label instead of a single path — matched exactly
                // here rather than inventing a different label format.
                file: "2 files",
                // Matches DescribeEdit's own detail-building exactly: each
                // edit becomes "- {old}\n+ {new}\n" (only the first line of
                // a multi-line old/new gets the "-"/"+" prefix —
                // continuation lines render unprefixed, a real quirk of the
                // backend's plain string interpolation, not a diff
                // formatter), and a blank line separates each file's edits.
                // The first file's edit is a genuine multi-line block
                // replacement (not just a couple of one-line swaps), and
                // the second file demonstrates the multi-file case.
                detail: """
                - const config = {
                  theme: 'light',
                  debug: false,
                  timeout: 3000
                }
                + const config = {
                  theme: 'dark',
                  debug: true,
                  timeout: 5000
                }

                - export const VERSION = '1.0.0'
                + export const VERSION = '1.1.0'
                """,
                files: [
                    PermissionRequestFile(
                        path: "web/src/App.tsx",
                        edits: [
                            PermissionRequestEdit(
                                old: "const config = {\n  theme: 'light',\n  debug: false,\n  timeout: 3000\n}",
                                new: "const config = {\n  theme: 'dark',\n  debug: true,\n  timeout: 5000\n}"
                            ),
                        ]
                    ),
                    PermissionRequestFile(
                        path: "web/src/utils.ts",
                        edits: [
                            PermissionRequestEdit(old: "export const VERSION = '1.0.0'", new: "export const VERSION = '1.1.0'"),
                        ]
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
