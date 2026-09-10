//
//  LoginUseCaseTests.swift
//  TIAGATests
//

import Testing
@testable import TIAGA

struct LoginUseCaseTests {

    @Test func test_login_succeeds_withValidCredentials() async throws {
        let useCase = LoginUseCase(repository: FakeAuthSessionRepository())

        let account = try await useCase.execute(
            email: FakeAuthSessionRepository.activeAccountEmail,
            password: FakeAuthSessionRepository.fixturePassword
        )

        #expect(account.email == FakeAuthSessionRepository.activeAccountEmail)
        #expect(account.status == .active)
    }

    @Test func test_login_fails_withInvalidCredentials() async throws {
        let useCase = LoginUseCase(repository: FakeAuthSessionRepository())

        await #expect(throws: LoginError.invalidCredentials) {
            _ = try await useCase.execute(
                email: FakeAuthSessionRepository.activeAccountEmail,
                password: "wrong-password"
            )
        }
    }

    @Test func test_login_fails_whenRateLimited() async throws {
        let useCase = LoginUseCase(repository: FakeAuthSessionRepository())

        await #expect(throws: LoginError.tooManyAttempts) {
            _ = try await useCase.execute(
                email: FakeAuthSessionRepository.rateLimitedEmail,
                password: FakeAuthSessionRepository.fixturePassword
            )
        }
    }

    @Test func test_login_fails_whenEmailIsMalformed() async throws {
        let useCase = LoginUseCase(repository: FakeAuthSessionRepository())

        await #expect(throws: LoginError.invalidCredentials) {
            _ = try await useCase.execute(email: "not-an-email", password: "anything")
        }
    }
}
