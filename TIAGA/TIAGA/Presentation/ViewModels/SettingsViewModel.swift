//
//  SettingsViewModel.swift
//  TIAGA
//

import Combine
import Foundation

/// Drives the Settings screen: usage, billing plan, and the privacy switch.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var usage: UsageSummary?
    @Published private(set) var plan: SubscriptionPlan?
    @Published private(set) var privacyPreference: PrivacyPreference?
    @Published private(set) var errorMessage: String?
    @Published private(set) var privacyErrorMessage: String?
    @Published private(set) var isLoading = false

    private let repository: AccountRepository
    private let loadAccountUsageUseCase: LoadAccountUsageUseCase
    private let updatePrivacyPreferenceUseCase: UpdatePrivacyPreferenceUseCase

    init(repository: AccountRepository? = nil) {
        let resolvedRepository: AccountRepository
        if let repository {
            resolvedRepository = repository
        } else if ProcessInfo.isRunningInXcodePreview {
            resolvedRepository = FakeAccountRepository()
        } else {
            #if DEBUG
            // Fake*Repository only inside Xcode Previews — everywhere else
            // (Simulator or a real device) talks to the real backend. See
            // AGENTS.md's "Live backend" policy. The debug usage-variant
            // override only makes sense against the fixture, so it's
            // checked first and still wins on a DEBUG build even outside
            // Previews (screenshot passes launch the real app, not a
            // Preview canvas).
            if let debugVariant = Self.debugUsageVariantOverride() {
                resolvedRepository = FakeAccountRepository(usageVariant: debugVariant)
            } else {
                resolvedRepository = RemoteAccountRepository()
            }
            #else
            resolvedRepository = RemoteAccountRepository()
            #endif
        }
        self.repository = resolvedRepository
        self.loadAccountUsageUseCase = LoadAccountUsageUseCase(repository: resolvedRepository)
        self.updatePrivacyPreferenceUseCase = UpdatePrivacyPreferenceUseCase(repository: resolvedRepository)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let snapshot = try await loadAccountUsageUseCase.execute()
            usage = snapshot.usage
            plan = snapshot.plan
        } catch let error as AccountUsageError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = AccountUsageError.accountUnreachable.errorDescription
        }

        // A usage/plan failure already surfaces via errorMessage above; the
        // privacy switch just stays nil (disabled) rather than doubling up
        // on the same "can't reach the account service" complaint.
        privacyPreference = try? await repository.loadPrivacyPreference()
    }

    func setImproveAIEnabled(_ enabled: Bool) async {
        guard let previous = privacyPreference else { return }
        privacyErrorMessage = nil
        // Optimistic, matching the web client (`PrivacyPanel.tsx`) — the
        // backend persists it per account, so a failure reverts rather than
        // blocking the switch until a round-trip completes.
        privacyPreference = PrivacyPreference(improveAIEnabled: enabled)
        do {
            try await updatePrivacyPreferenceUseCase.execute(PrivacyPreference(improveAIEnabled: enabled))
        } catch let error as PrivacyPreferenceError {
            privacyPreference = previous
            privacyErrorMessage = error.errorDescription
        } catch {
            privacyPreference = previous
            privacyErrorMessage = PrivacyPreferenceError.updateFailedWhileOffline.errorDescription
        }
    }

    #if DEBUG
    /// Reads `TIAGA_DEBUG_USAGE_VARIANT` (pass via
    /// `SIMCTL_CHILD_TIAGA_DEBUG_USAGE_VARIANT` to `xcrun simctl launch`) so
    /// a screenshot pass can force any of `UsageSummary`'s three real states
    /// — "subscription" (default), "admin", "noActivePlan" — without a live
    /// account in each state.
    private static func debugUsageVariantOverride() -> FakeAccountRepository.UsageVariant? {
        switch ProcessInfo.processInfo.environment["TIAGA_DEBUG_USAGE_VARIANT"] {
        case "admin": return .admin
        case "noActivePlan": return .noActivePlan
        case "subscription": return .subscription
        default: return nil
        }
    }
    #endif
}
