//
//  RestoreSessionUseCaseTests.swift
//  TIAGATests
//

import Testing
@testable import TIAGA

struct RestoreSessionUseCaseTests {

    @Test func test_restoreSession_returnsActiveAccount_whenSessionIsValid() async throws {
        let repository = FakeAuthSessionRepository()
        _ = try await repository.login(
            email: FakeAuthSessionRepository.activeAccountEmail,
            password: FakeAuthSessionRepository.fixturePassword
        )
        let useCase = RestoreSessionUseCase(repository: repository)

        let outcome = try await useCase.execute()

        #expect(outcome == .authenticated(Account(email: FakeAuthSessionRepository.activeAccountEmail, status: .active, roles: [])))
    }

    @Test func test_restoreSession_returnsUnauthenticated_whenNoSessionExists() async throws {
        let useCase = RestoreSessionUseCase(repository: FakeAuthSessionRepository())

        let outcome = try await useCase.execute()

        #expect(outcome == .unauthenticated)
    }

    @Test func test_restoreSession_fails_whenConnectionIsUnavailable() async throws {
        let repository = FakeAuthSessionRepository()
        repository.shouldFailRestoreSession = true
        let useCase = RestoreSessionUseCase(repository: repository)

        await #expect(throws: SessionRestoreError.connectionUnavailable) {
            _ = try await useCase.execute()
        }
    }
}
