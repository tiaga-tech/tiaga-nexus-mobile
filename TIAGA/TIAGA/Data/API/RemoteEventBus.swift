//
//  RemoteEventBus.swift
//  TIAGA
//

import Foundation

/// Multiplexes the backend's single, app-wide SSE stream (`GET /api/events`)
/// so multiple `Remote*Repository` implementations can each subscribe to
/// just the event `type`s they care about, instead of each opening its own
/// separate connection. Mirrors the real web client's own architecture —
/// one shared `EventSource`, fanned out by a `type` field to whichever hook
/// cares (`useDevices.ts`'s `handleEvent`, etc.) — every frame here is a
/// bare `data: {...}` line with no SSE `event:` name at all
/// (`EventHub.cs`/`EventsController.cs`): events are discriminated purely
/// by a `"type"` key inside the JSON payload.
nonisolated final class RemoteEventBus: @unchecked Sendable {
    static let shared = RemoteEventBus()

    private let eventStream: TIAGAEventStream
    private let lock = NSLock()
    private var continuationsByType: [String: [UUID: AsyncStream<Data>.Continuation]] = [:]
    private var isConnected = false

    init(eventStream: TIAGAEventStream = TIAGAEventStream()) {
        self.eventStream = eventStream
    }

    /// Events of one `type` (e.g. "permission", "device"), as raw JSON
    /// payload data for the caller to decode further. Each call gets its
    /// own independent stream; the underlying SSE connection is shared and
    /// started lazily on the first subscriber of any type.
    func events(ofType type: String) -> AsyncStream<Data> {
        events(ofTypes: [type])
    }

    /// Events of any of several `type`s, merged into one stream — e.g. Chat
    /// needs `voice`/`tool`/`error`/`turn_start`/`turn_end`/`compaction`/
    /// `usage`/`cancelled` all funneled together, matching the web client's
    /// single `es.onmessage` handler branching on `type` rather than one
    /// subscription per type.
    func events(ofTypes types: Set<String>) -> AsyncStream<Data> {
        connectIfNeeded()
        let id = UUID()
        return AsyncStream { continuation in
            self.lock.withLock {
                for type in types {
                    self.continuationsByType[type, default: [:]][id] = continuation
                }
            }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock {
                    for type in types {
                        self?.continuationsByType[type]?[id] = nil
                    }
                }
            }
        }
    }

    private func connectIfNeeded() {
        let alreadyConnected = lock.withLock {
            defer { isConnected = true }
            return isConnected
        }
        guard !alreadyConnected else { return }

        Task { [weak self] in
            while true {
                guard let self else { return }
                do {
                    for try await event in self.eventStream.events() {
                        self.dispatch(event.data)
                    }
                } catch {
                    // Connection dropped — reconnect after a short delay,
                    // matching the browser's own `EventSource` auto-reconnect
                    // behavior on a dropped SSE connection.
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func dispatch(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else { return }
        let continuations = lock.withLock { Array((continuationsByType[type] ?? [:]).values) }
        for continuation in continuations {
            continuation.yield(data)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
