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

    init(repository: PermissionRequestRepository = FakePermissionRequestRepository()) {
        self.reviewPermissionRequestUseCase = ReviewPermissionRequestUseCase(repository: repository)
        startObserving(repository)
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
