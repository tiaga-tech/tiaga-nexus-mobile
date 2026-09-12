//
//  ReviewPermissionRequestUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

/// Thin purpose-built fake for `ReviewPermissionRequestUseCase` — a single
/// resolvable request and counters for what got called.
private final class StubPermissionRequestRepository: PermissionRequestRepository {
    var hasPendingRequest = true
    private(set) var approveCallCount = 0
    private(set) var denyCallCount = 0

    func observePendingRequests() -> AsyncStream<[PermissionRequest]> {
        AsyncStream { $0.finish() }
    }

    func approve(_ id: String) async throws {
        guard hasPendingRequest else { throw PermissionRequestError.requestAlreadyResolved }
        approveCallCount += 1
        hasPendingRequest = false
    }

    func deny(_ id: String) async throws {
        guard hasPendingRequest else { throw PermissionRequestError.requestAlreadyResolved }
        denyCallCount += 1
        hasPendingRequest = false
    }
}

struct ReviewPermissionRequestUseCaseTests {

    @Test func test_reviewPermissionRequest_approves_whenRequestIsPending() async throws {
        let repository = StubPermissionRequestRepository()
        let useCase = ReviewPermissionRequestUseCase(repository: repository)

        try await useCase.approve("permission-1")

        #expect(repository.approveCallCount == 1)
    }

    @Test func test_reviewPermissionRequest_denies_whenRequestIsPending() async throws {
        let repository = StubPermissionRequestRepository()
        let useCase = ReviewPermissionRequestUseCase(repository: repository)

        try await useCase.deny("permission-1")

        #expect(repository.denyCallCount == 1)
    }

    @Test func test_reviewPermissionRequest_fails_whenRequestAlreadyResolved() async throws {
        let repository = StubPermissionRequestRepository()
        repository.hasPendingRequest = false
        let useCase = ReviewPermissionRequestUseCase(repository: repository)

        await #expect(throws: PermissionRequestError.requestAlreadyResolved) {
            try await useCase.approve("permission-1")
        }
        #expect(repository.approveCallCount == 0)
    }
}
