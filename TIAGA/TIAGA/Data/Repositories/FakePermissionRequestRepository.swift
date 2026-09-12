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
                // permission request, and a single file's `edits` array can
                // itself hold more than one hunk (non-contiguous sections of
                // the same file changing together, e.g. an import line and
                // an unrelated block further down). When there's more than
                // one file, PermissionManager.cs's DescribeEdit uses
                // "{count} files" as the label instead of a single path —
                // matched exactly here. Five files (one long enough to force
                // truncation) also exercises the tab row's horizontal
                // scroll, which the web client's own `overflow-x-auto` tab
                // bar needs for the same reason.
                file: "5 files",
                // `detail` matches DescribeEdit's own text-building exactly
                // (only the first line of a multi-line old/new gets the
                // "-"/"+" prefix — continuation lines render unprefixed, a
                // quirk of the backend's plain string interpolation). Kept
                // here for wire fidelity, but the app doesn't render this
                // flattened text for `.edit` — it builds the diff view from
                // `files` below via `PermissionEditDiff`, matching the web
                // client's own `DiffView.tsx`, which does the same.
                detail: """
                - import { useState } from 'react'
                + import { useState, useEffect } from 'react'
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

                - const [messages, setMessages] = useState<Message[]>([])
                + const [messages, setMessages] = useState<Message[]>(initialMessages)

                - className="flex flex-col gap-2"
                + className="flex flex-col gap-3"

                - md: 'markdown', sql: 'sql',
                + md: 'markdown', sql: 'sql', dockerfile: 'dockerfile',
                """,
                files: [
                    PermissionRequestFile(
                        path: "web/src/App.tsx",
                        // Two non-contiguous edits in the same file — the
                        // import line and the config block are unrelated
                        // sections, not one continuous hunk. Exercises
                        // `PermissionEditFilesView` rendering more than one
                        // diff block stacked under a single file tab.
                        edits: [
                            PermissionRequestEdit(
                                old: "import { useState } from 'react'",
                                new: "import { useState, useEffect } from 'react'"
                            ),
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
                    PermissionRequestFile(
                        path: "web/src/hooks/useConversation.ts",
                        edits: [
                            PermissionRequestEdit(
                                old: "const [messages, setMessages] = useState<Message[]>([])",
                                new: "const [messages, setMessages] = useState<Message[]>(initialMessages)"
                            ),
                        ]
                    ),
                    PermissionRequestFile(
                        path: "web/src/components/MessageList.tsx",
                        edits: [
                            PermissionRequestEdit(
                                old: "className=\"flex flex-col gap-2\"",
                                new: "className=\"flex flex-col gap-3\""
                            ),
                        ]
                    ),
                    PermissionRequestFile(
                        path: "web/src/lib/highlight.ts",
                        edits: [
                            PermissionRequestEdit(
                                old: "md: 'markdown', sql: 'sql',",
                                new: "md: 'markdown', sql: 'sql', dockerfile: 'dockerfile',"
                            ),
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
