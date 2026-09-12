//
//  TIAGAEventStream.swift
//  TIAGA
//

import Foundation

/// Wraps the backend's live-updates stream (`GET /api/events`, Server-Sent
/// Events — the real backend uses SSE to the web client and WebSocket only
/// to harnesses). Shared transport only: this type yields raw named event
/// frames; each feature's repository decodes the payload it cares about
/// (device presence, agent state, streaming chat tokens) and ignores the rest.
final class TIAGAEventStream {

    /// One `event:`/`data:` frame from the SSE stream. `nonisolated` (and
    /// `Sendable`) since it's a plain value crossing out of this class's
    /// otherwise-MainActor-isolated context into background parsing/test
    /// code — without it, the compiler treats even its synthesized
    /// `Equatable` conformance as MainActor-isolated too.
    nonisolated struct Event: Equatable, Sendable {
        let name: String?
        let data: Data
    }

    private let baseURL: URL
    private let urlSession: URLSession

    init(baseURL: URL = TIAGAAPIClient.defaultBaseURL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    /// Connects and yields events until the task is cancelled or the
    /// connection drops (in which case the stream finishes with an error —
    /// callers are responsible for deciding whether/when to reconnect).
    ///
    /// Yields on every `data:` line directly, rather than buffering until a
    /// blank line marks the end of a frame (the SSE spec's actual framing,
    /// and this file's original approach): confirmed empirically (a local
    /// raw-socket SSE server + a standalone `URLSession.bytes(for:)` test)
    /// that `AsyncBytes.lines` never yields an empty-string element for a
    /// blank line at all — it silently collapses `"data: x\n\n"` down to a
    /// single non-empty line, never producing the trailing empty one. Any
    /// parser waiting for `line.isEmpty` to flush an accumulated event will
    /// therefore never yield anything, ever — which is exactly what made
    /// every live update (permission requests, device presence) silently
    /// never arrive, only ever visible after a relaunch's fresh REST fetch.
    /// Safe here because the real backend only ever sends single-line JSON
    /// data per event (`EventHub.PublishAsync` → `JsonSerializer.Serialize`,
    /// which escapes rather than embeds real newlines) — a multi-line
    /// `data:` payload would need a different fix, but this backend never
    /// sends one.
    func events() -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = URLRequest(url: baseURL.appendingPathComponent("events"))
                    let (bytes, response) = try await urlSession.bytes(for: request)

                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        continuation.finish(throwing: APITransportError.unreachable)
                        return
                    }

                    var eventName: String?
                    for try await line in bytes.lines {
                        if let event = Self.parse(line: line, eventName: &eventName) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Pure parsing step for one incoming line, given the `event:` name
    /// accumulated so far (mutated in place, matching SSE's stateful
    /// framing — a `data:` line completes and clears it). Returns the
    /// completed event on a `data:` line, `nil` otherwise (a blank line, a
    /// `: comment` heartbeat, or an `event:` line that only updated
    /// `eventName`). Exposed for testing without a real network connection
    /// — see `events()`'s doc comment for why this yields per-line rather
    /// than buffering until a blank line.
    static func parse(line: String, eventName: inout String?) -> Event? {
        if line.hasPrefix("event:") {
            eventName = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
            return nil
        }
        if line.hasPrefix("data:") {
            let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            defer { eventName = nil }
            return Event(name: eventName, data: Data(payload.utf8))
        }
        return nil
    }
}
