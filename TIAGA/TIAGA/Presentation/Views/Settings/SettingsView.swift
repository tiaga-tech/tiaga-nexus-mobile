//
//  SettingsView.swift
//  TIAGA
//

import SwiftUI

/// The Settings screen: account usage, billing plan (read-only), the
/// privacy switch, and Log Out. Mirrors the web client's Settings modal's
/// Usage/Billing/Privacy tabs (`SettingsModal.tsx`) flattened into one
/// scrolling screen — Devices already has its own root-level screen
/// (Section 7) and Integrations (MCP) has no domain concept in this app,
/// so neither is duplicated here.
struct SettingsView: View {
    let account: Account
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TIAGASpacing.lg) {
                    accountCard
                    if let message = viewModel.errorMessage {
                        errorCard(message)
                    } else {
                        usageCard
                        billingCard
                    }
                    privacyCard
                    logOutButton
                }
                .padding(TIAGASpacing.lg)
            }
            .background(TIAGAColor.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await viewModel.load() }
    }

    private var accountCard: some View {
        TIAGACard {
            VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
                // Not badging `account.roles.contains(.admin)` here: that
                // Account comes from the auth debug-route override, sourced
                // independently of FakeAccountRepository's usage variant —
                // the two would only ever agree once a real backend session
                // resolves both from the same account.
                Text(account.email)
                    .font(TIAGATypography.headline)
                    .foregroundStyle(TIAGAColor.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func errorCard(_ message: String) -> some View {
        TIAGACard {
            Text(message)
                .font(TIAGATypography.subheadline)
                .foregroundStyle(TIAGAColor.statusDanger)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var usageCard: some View {
        if let usage = viewModel.usage {
            TIAGACard {
                switch usage {
                case .subscription(let subscriptionUsage):
                    subscriptionUsageContent(subscriptionUsage)
                case .admin(let adminUsage):
                    adminUsageContent(adminUsage)
                case .noActivePlan(let extraCreditsUsd):
                    noActivePlanUsageContent(extraCreditsUsd: extraCreditsUsd)
                }
            }
        }
    }

    private func subscriptionUsageContent(_ usage: SubscriptionUsage) -> some View {
        VStack(alignment: .leading, spacing: TIAGASpacing.md) {
            VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
                Text("Usage")
                    .font(TIAGATypography.headline)
                    .foregroundStyle(TIAGAColor.textPrimary)
                Text(
                    "A session starts with your first message and lasts five hours; its cap fully resets when the session ends. Weekly usage spreads your plan evenly across the week and resets when a new week starts."
                )
                .font(TIAGATypography.caption)
                .foregroundStyle(TIAGAColor.textTertiary)
            }
            UsageMeterView(label: "This session", percentage: usage.sessionPercentage, resetsAt: usage.sessionResetsAt)
            UsageMeterView(label: "This week", percentage: usage.weeklyPercentage, resetsAt: usage.weeklyResetsAt)
            if usage.extraCreditsUsd > 0 {
                HStack {
                    Text("Extra credits (used after limits fill up)")
                        .font(TIAGATypography.caption)
                        .foregroundStyle(TIAGAColor.textSecondary)
                    Spacer()
                    Text(Self.usd(usage.extraCreditsUsd))
                        .font(TIAGATypography.caption)
                        .foregroundStyle(TIAGAColor.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func adminUsageContent(_ usage: AdminUsage) -> some View {
        VStack(alignment: .leading, spacing: TIAGASpacing.md) {
            VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
                Text("Your usage")
                    .font(TIAGATypography.headline)
                    .foregroundStyle(TIAGAColor.textPrimary)
                Text("Admin accounts have no limits; this is what your usage actually costs.")
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.textTertiary)
            }
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: TIAGASpacing.sm) {
                usageStat(label: "This session", usd: usage.sessionUsd)
                usageStat(label: "Past 7 days", usd: usage.weeklyUsd)
                usageStat(label: "Past 30 days", usd: usage.last30DaysUsd)
                usageStat(label: "All time", usd: usage.allTimeUsd)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func usageStat(label: String, usd: Double) -> some View {
        VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
            Text(label)
                .font(TIAGATypography.caption)
                .foregroundStyle(TIAGAColor.textTertiary)
            Text(Self.usd(usd))
                .font(TIAGATypography.subheadline)
                .foregroundStyle(TIAGAColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TIAGASpacing.sm)
        .background(TIAGAColor.surface, in: RoundedRectangle(cornerRadius: TIAGARadius.sm, style: .continuous))
    }

    private func noActivePlanUsageContent(extraCreditsUsd: Double) -> some View {
        VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
            Text("No active plan")
                .font(TIAGATypography.headline)
                .foregroundStyle(TIAGAColor.textPrimary)
            // Web's own copy points to its Billing tab; this app has no
            // separate tab, just the Billing section right below.
            Text("Usage meters appear here once you're on a plan — see Billing below.")
                .font(TIAGATypography.caption)
                .foregroundStyle(TIAGAColor.textTertiary)
            if extraCreditsUsd > 0 {
                Text("You have \(Self.usd(extraCreditsUsd)) of extra credits; TIAGA keeps working on those in the meantime.")
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var billingCard: some View {
        if let plan = viewModel.plan {
            TIAGACard {
                VStack(alignment: .leading, spacing: TIAGASpacing.sm) {
                    switch plan {
                    case .active(let activePlan):
                        Text("\(activePlan.tierName) plan")
                            .font(TIAGATypography.headline)
                            .foregroundStyle(TIAGAColor.textPrimary)
                        Text(planStatusText(activePlan))
                            .font(TIAGATypography.caption)
                            .foregroundStyle(TIAGAColor.textTertiary)
                    case .none:
                        Text("No active plan")
                            .font(TIAGATypography.headline)
                            .foregroundStyle(TIAGAColor.textPrimary)
                        Text("Pick a plan or redeem a code on the web version.")
                            .font(TIAGATypography.caption)
                            .foregroundStyle(TIAGAColor.textTertiary)
                    }
                    // Deliberately plain text, no link — plan management
                    // (upgrading, redeeming a code, cancelling) only
                    // happens on the web version.
                    Text("Manage your plan on the web version.")
                        .font(TIAGATypography.caption)
                        .foregroundStyle(TIAGAColor.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Matches the web client's own `usd = (n) => \`$${n.toFixed(2)}\``
    /// (`UsagePanel.tsx`) exactly — a hardcoded "$", not `.currency(code:)`,
    /// since that's locale-dependent and can render as "USD 3.50" instead
    /// of "$3.50" depending on the device's region. This is a US-dollar-only
    /// product regardless of where the operator's phone is set.
    private static func usd(_ amount: Double) -> String {
        "$" + String(format: "%.2f", amount)
    }

    /// Matches `BillingPanel.tsx`'s exact status-line precedence.
    private func planStatusText(_ plan: ActivePlan) -> String {
        let ends = plan.endsAt.formatted(date: .abbreviated, time: .omitted)
        switch plan.renewalStatus {
        case .switchingTo(let tierName):
            return "Until \(ends), then switching to \(tierName)."
        case .queued:
            return "Until \(ends), with more plan time queued after."
        case .renewing:
            return "Renews on \(ends)."
        case .ending:
            return "Ends on \(ends)."
        }
    }

    private var privacyCard: some View {
        TIAGACard {
            HStack(alignment: .top, spacing: TIAGASpacing.md) {
                VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
                    Text("Use my conversations to improve AI")
                        .font(TIAGATypography.body)
                        .foregroundStyle(TIAGAColor.textPrimary)
                    Text(
                        "When this is on, your conversations may be used by our AI partners to improve their models. Turn it off and your conversations are never stored by them or used for training."
                    )
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.textTertiary)
                    Text("Turning this off can use up your usage allowance faster.")
                        .font(TIAGATypography.caption)
                        .foregroundStyle(TIAGAColor.statusWarning)
                    if let message = viewModel.privacyErrorMessage {
                        Text(message)
                            .font(TIAGATypography.caption)
                            .foregroundStyle(TIAGAColor.statusDanger)
                    }
                }
                Spacer(minLength: TIAGASpacing.sm)
                Toggle("", isOn: Binding(
                    get: { viewModel.privacyPreference?.improveAIEnabled ?? false },
                    set: { newValue in
                        Task { await viewModel.setImproveAIEnabled(newValue) }
                    }
                ))
                .labelsHidden()
                .disabled(viewModel.privacyPreference == nil)
            }
        }
    }

    private var logOutButton: some View {
        Button("Log Out", role: .destructive) {
            Task { await authViewModel.logout() }
        }
        .buttonStyle(.glass)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SettingsView(
        account: Account(email: "operator@tiaga.tech", status: .active, roles: []),
        authViewModel: AuthViewModel()
    )
}
