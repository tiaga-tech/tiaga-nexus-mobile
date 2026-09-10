//
//  RedeemInviteCodeUseCaseTests.swift
//  TIAGATests
//

import Testing
@testable import TIAGA

struct RedeemInviteCodeUseCaseTests {

    private func loggedInWaitlistedAccount(_ repository: FakeAuthSessionRepository) async throws -> Account {
        try await repository.login(
            email: FakeAuthSessionRepository.waitlistedAccountEmail,
            password: FakeAuthSessionRepository.fixturePassword
        )
    }

    @Test func test_redeemInviteCode_activatesWaitlistedAccount_whenCodeIsValid() async throws {
        let repository = FakeAuthSessionRepository()
        let waitlisted = try await loggedInWaitlistedAccount(repository)
        let useCase = RedeemInviteCodeUseCase(repository: repository)

        let activated = try await useCase.execute(code: FakeAuthSessionRepository.validInviteCode, for: waitlisted)

        #expect(activated.status == .active)
        #expect(activated.email == waitlisted.email)
    }

    @Test func test_redeemInviteCode_fails_whenCodeIsInvalid() async throws {
        let repository = FakeAuthSessionRepository()
        let waitlisted = try await loggedInWaitlistedAccount(repository)
        let useCase = RedeemInviteCodeUseCase(repository: repository)

        await #expect(throws: InviteCodeError.codeInvalid) {
            _ = try await useCase.execute(code: "WRONG-CODE", for: waitlisted)
        }
    }

    @Test func test_redeemInviteCode_fails_whenAccountIsAlreadyActive() async throws {
        let repository = FakeAuthSessionRepository()
        let useCase = RedeemInviteCodeUseCase(repository: repository)
        let activeAccount = Account(email: FakeAuthSessionRepository.activeAccountEmail, status: .active, roles: [])

        await #expect(throws: InviteCodeError.accountAlreadyActive) {
            _ = try await useCase.execute(code: FakeAuthSessionRepository.validInviteCode, for: activeAccount)
        }
    }
}
