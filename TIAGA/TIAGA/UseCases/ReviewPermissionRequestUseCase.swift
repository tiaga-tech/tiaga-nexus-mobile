//
//  ReviewPermissionRequestUseCase.swift
//  TIAGA
//

import Foundation

/// Approves or denies a pending permission request, backing the approval
/// overlay's two buttons.
///
/// Business Rule: cannot act on a request that's already been resolved —
/// there's nothing left to approve or deny.
struct ReviewPermissionRequestUseCase {
    let repository: PermissionRequestRepository

    func approve(_ requestID: String) async throws {
        do {
            try await repository.approve(requestID)
        } catch is PermissionRequestError {
            throw PermissionRequestError.requestAlreadyResolved
        }
    }

    func deny(_ requestID: String) async throws {
        do {
            try await repository.deny(requestID)
        } catch is PermissionRequestError {
            throw PermissionRequestError.requestAlreadyResolved
        }
    }
}
