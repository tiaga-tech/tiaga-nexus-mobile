//
//  APITransportError.swift
//  TIAGA
//

import Foundation

/// Infra-level failure states from talking to the TIAGA backend. This is
/// transport plumbing, not a domain error — a feature's repository catches
/// this and maps it into its own operator-facing error type (e.g. a 403 on
/// `/api/chat` means something different than a 403 on `/api/devices`).
/// Views and ViewModels must never see `APITransportError` directly.
enum APITransportError: Error, Equatable {
    /// The request never reached the backend (no connection, DNS failure, timeout).
    case unreachable
    /// The backend rejected the request for lacking a valid session (HTTP 401).
    case unauthorized
    /// A response arrived but didn't match the shape the caller expected.
    case decodingFailed
    /// Any other non-2xx response, carrying the status code and the backend's
    /// own `{ "error": "..." }` message when it sent one, so a repository can
    /// branch on the specific status for its own endpoint's meaning.
    case serverError(status: Int, message: String?)
}
