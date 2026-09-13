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
    private var connectionTask: Task<Void, Never>?

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

        let task = Task { [weak self] in
            while true {
                guard let self, !Task.isCancelled else { return }
                do {
                    for try await event in self.eventStream.events() {
                        self.dispatch(event.data)
                    }
                } catch {
                    // Connection dropped — reconnect after a short delay,
                    // matching the browser's own `EventSource` auto-reconnect
                    // behavior on a dropped SSE connection.
                }
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        lock.withLock { connectionTask = task }
    }

    /// Tears down the current SSE connection and drops every subscriber.
    /// Call this on logout: the connection above is opened once per process
    /// and, once live, never re-reads the cookie jar on its own — so
    /// logging into a *different* account without restarting the app would
    /// otherwise keep the stream tied to whichever session was active when
    /// it first connected. Confirmed against the real web client
    /// (`useConversation.ts`), which gets this for free by closing its
    /// `EventSource` (`es.close()`) whenever the authenticated shell
    /// unmounts and opening a fresh one on remount; this app has no
    /// equivalent unmount signal since the bus is a long-lived singleton,
    /// so `logout` has to drive it explicitly instead. Finishing every
    /// continuation (not just cancelling the network task) also guarantees
    /// a screen still animating off-screen from the old account can't go on
    /// receiving events meant for whichever account signs in next.
    func disconnect() {
        let (task, continuations) = lock.withLock {
            defer {
                isConnected = false
                connectionTask = nil
                continuationsByType.removeAll()
            }
            return (connectionTask, continuationsByType.values.flatMap { $0.values })
        }
        task?.cancel()
        for continuation in continuations {
            continuation.finish()
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
