//
//  SessionCookieStore.swift
//  TIAGA
//

import Foundation

/// Inspects and clears the backend's session cookie — a long, sliding cookie
/// (`URLSession`'s cookie storage carries it automatically on every request
/// to the backend's origin; this type exists for the two things that aren't
/// automatic: checking whether one exists before making a network call, and
/// clearing it on logout).
struct SessionCookieStore {
    private let baseURL: URL
    private let cookieStorage: HTTPCookieStorage

    init(baseURL: URL = TIAGAAPIClient.defaultBaseURL, cookieStorage: HTTPCookieStorage = .shared) {
        self.baseURL = baseURL
        self.cookieStorage = cookieStorage
    }

    /// Whether a cookie is currently stored for the backend's origin. Not
    /// proof the session is still valid server-side — just cheap enough to
    /// decide whether restoring a session is worth a network round-trip.
    var hasSessionCookie: Bool {
        !(cookieStorage.cookies(for: baseURL) ?? []).isEmpty
    }

    /// Clears every cookie for the backend's origin. `LogoutUseCase` (Section
    /// 3) calls this unconditionally, even if the remote logout call fails —
    /// a user must never be stuck "logged in" locally by a network error.
    func clearSession() {
        for cookie in cookieStorage.cookies(for: baseURL) ?? [] {
            cookieStorage.deleteCookie(cookie)
        }
    }
}
