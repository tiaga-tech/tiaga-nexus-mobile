//
//  LogoutUseCaseTests.swift
//  TIAGATests
//

import Testing
@testable import TIAGA

struct LogoutUseCaseTests {

    @Test func test_logout_clearsLocalSession_evenWhenRemoteInvalidationFails() async throws {
        let repository = FakeAuthSessionRepository()
        _ = try await repository.login(
            email: FakeAuthSessionRepository.activeAccountEmail,
            password: FakeAuthSessionRepository.fixturePassword
        )
        repository.shouldFailRemoteLogout = true
        let useCase = LogoutUseCase(repository: repository)

        await useCase.execute()

        let remainingSession = try await repository.restoreSession()
        #expect(remainingSession == nil)
    }
}
