//
//  PermissionRequestOverlayViewModel.swift
//  TIAGA
//

import Combine
import Foundation
import SwiftUI

/// Drives the app-wide permission approval overlay. Root-scoped (owned by
/// `FleetConsoleRootView`, not any one screen) since a request can arrive
/// while the operator is anywhere in the app.
///
/// When more than one request is pending, they queue oldest-first — only
/// `currentRequest` (the front of the queue) is ever shown, and the next one
/// surfaces automatically once the current one resolves.
@MainActor
final class PermissionRequestOverlayViewModel: ObservableObject {
    @Published private(set) var currentRequest: PermissionRequest?
    @Published private(set) var errorMessage: String?

    private let reviewPermissionRequestUseCase: ReviewPermissionRequestUseCase

    init(repository: PermissionRequestRepository? = nil) {
        // Fake*Repository only inside Xcode Previews — everywhere else
        // (Simulator or a real device) talks to the real backend. See
        // AGENTS.md's "Live backend" policy.
        let resolvedRepository = repository ?? (
            ProcessInfo.isRunningInXcodePreview ? FakePermissionRequestRepository() : RemotePermissionRequestRepository()
        )
        self.reviewPermissionRequestUseCase = ReviewPermissionRequestUseCase(repository: resolvedRepository)
        startObserving(resolvedRepository)
    }

    func approve() async {
        guard let request = currentRequest else { return }
        errorMessage = nil
        do {
            try await reviewPermissionRequestUseCase.approve(request.id)
        } catch let error as PermissionRequestError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = PermissionRequestError.requestAlreadyResolved.errorDescription
        }
    }

    func deny() async {
        guard let request = currentRequest else { return }
        errorMessage = nil
        do {
            try await reviewPermissionRequestUseCase.deny(request.id)
        } catch let error as PermissionRequestError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = PermissionRequestError.requestAlreadyResolved.errorDescription
        }
    }

    private func startObserving(_ repository: PermissionRequestRepository) {
        let stream = repository.observePendingRequests()
        Task { [weak self] in
            for await requests in stream {
                self?.currentRequest = requests.first
            }
        }
    }
}
