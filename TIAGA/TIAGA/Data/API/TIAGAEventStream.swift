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

    /// One `event:`/`data:` frame from the SSE stream.
    struct Event {
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
                    var dataLines: [String] = []

                    for try await line in bytes.lines {
                        if line.isEmpty {
                            if !dataLines.isEmpty {
                                let payload = dataLines.joined(separator: "\n")
                                continuation.yield(Event(name: eventName, data: Data(payload.utf8)))
                            }
                            eventName = nil
                            dataLines = []
                            continue
                        }
                        if line.hasPrefix("event:") {
                            eventName = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            dataLines.append(line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces))
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
}
