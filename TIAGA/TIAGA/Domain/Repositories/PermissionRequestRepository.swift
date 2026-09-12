//
//  PermissionRequestRepository.swift
//  TIAGA
//

import Foundation

/// The app-wide stream of pending permission requests. Protocol only — see
/// `Data/Repositories/FakePermissionRequestRepository.swift` for the
/// (fixture-backed, no-network) implementation. Never call this directly
/// from a View; go through `ReviewPermissionRequestUseCase`.
protocol PermissionRequestRepository {
    /// The live list of unresolved requests. Mirrors the real backend's SSE
    /// `request`/`resolved` events — a new pending request appears, a
    /// resolved one disappears.
    func observePendingRequests() -> AsyncStream<[PermissionRequest]>

    func approve(_ id: String) async throws
    func deny(_ id: String) async throws
}
