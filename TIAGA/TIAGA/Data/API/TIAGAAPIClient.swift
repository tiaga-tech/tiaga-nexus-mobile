//
//  TIAGAAPIClient.swift
//  TIAGA
//

import Foundation

/// The subset of `URLSession` this client depends on, so tests can inject a
/// fake transport instead of hitting the network. `URLSession` conforms via
/// the extension below.
protocol URLDataSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLDataSession {}

/// Thin HTTP client for the TIAGA backend. Shared transport only — this type
/// knows nothing about specific endpoints or domain payloads; each feature's
/// `Data/Repositories` implementation builds its own requests on top of it
/// and maps `APITransportError` into its own operator-facing error type.
///
/// Authentication rides `URLSession`'s cookie storage automatically (the
/// backend uses a long, sliding session cookie, not a bearer token the
/// client manages) — see `SessionCookieStore` for inspecting/clearing it.
final class TIAGAAPIClient {

    /// The real backend's production origin (web and API are same-origin
    /// behind a reverse proxy — see `deploy/Caddyfile.example` in tiaga-nexus).
    static let defaultBaseURL = URL(string: "https://tiaga.tech/api")!

    private let baseURL: URL
    private let session: URLDataSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL = TIAGAAPIClient.defaultBaseURL, session: URLDataSession = URLSession.shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    /// GET a JSON resource.
    func get<Response: Decodable>(_ path: String) async throws -> Response {
        let data = try await sendRaw(path: path, method: "GET", body: nil)
        return try decodeOrThrow(data)
    }

    /// POST a JSON body, expecting a JSON response back.
    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        let data = try await sendRaw(path: path, method: "POST", body: try encoder.encode(body))
        return try decodeOrThrow(data)
    }

    /// POST a JSON body, expecting no meaningful response body (e.g. `/api/chat`).
    func postExpectingNoContent<Body: Encodable>(_ path: String, body: Body) async throws {
        _ = try await sendRaw(path: path, method: "POST", body: try encoder.encode(body))
    }

    /// PUT a JSON body, expecting a JSON response back (e.g. `/api/devices/{id}`).
    func put<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        let data = try await sendRaw(path: path, method: "PUT", body: try encoder.encode(body))
        return try decodeOrThrow(data)
    }

    /// POST with no body and no meaningful response body (e.g. `/api/reset`).
    func postExpectingNoContent(_ path: String) async throws {
        _ = try await sendRaw(path: path, method: "POST", body: nil)
    }

    private func decodeOrThrow<Response: Decodable>(_ data: Data) throws -> Response {
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APITransportError.decodingFailed
        }
    }

    private func sendRaw(path: String, method: String, body: Data?) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APITransportError.unreachable
        }

        guard let http = response as? HTTPURLResponse else {
            throw APITransportError.unreachable
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw APITransportError.unauthorized
            }
            let message = try? decoder.decode(APIErrorBody.self, from: data).error
            throw APITransportError.serverError(status: http.statusCode, message: message)
        }

        return data
    }
}

/// The backend's standard error body shape: `{ "error": "..." }`.
private struct APIErrorBody: Decodable {
    let error: String
}
