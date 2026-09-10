//
//  WaitlistGateView.swift
//  TIAGA
//

import SwiftUI

/// Shown after a successful sign-in to an account still on TIAGA's private
/// beta waitlist, instead of the fleet console. Message + invite code
/// redemption only — the web client also has a beta-application form; this
/// mobile version leaves that out since redeeming a code already in hand is
/// the action a mobile user is most likely to take on the spot.
struct WaitlistGateView: View {
    @ObservedObject var viewModel: AuthViewModel
    let account: Account

    var body: some View {
        VStack(spacing: TIAGASpacing.lg) {
            Spacer()

            Text("You're on the waiting list")
                .font(TIAGATypography.screenTitle)
                .foregroundStyle(TIAGAColor.textPrimary)
                .multilineTextAlignment(.center)

            Text("TIAGA is in private beta. We'll email \(account.email) when a spot opens up — or enter an invite code below if you already have one.")
                .font(TIAGATypography.subheadline)
                .foregroundStyle(TIAGAColor.textSecondary)
                .multilineTextAlignment(.center)

            TextField(
                "",
                text: $viewModel.inviteCodeField,
                prompt: Text("Invite code").foregroundStyle(TIAGAColor.textTertiary)
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .font(TIAGATypography.command)
            .foregroundStyle(TIAGAColor.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, TIAGASpacing.md)
            .padding(.vertical, TIAGASpacing.sm)
            .background(TIAGAColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.md, style: .continuous))

            if let message = viewModel.inviteCodeErrorMessage {
                Text(message)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.statusDanger)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await viewModel.submitInviteCode() }
            } label: {
                Text(viewModel.isSubmitting ? "Redeeming…" : "Redeem Code")
                    .font(TIAGATypography.body)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(TIAGAColor.textOnAccent)
            .padding(.vertical, TIAGASpacing.sm)
            .background(TIAGAColor.brandAccent.opacity(viewModel.isSubmitting || viewModel.inviteCodeField.isEmpty ? 0.3 : 0.8))
            .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.md, style: .continuous))
            .disabled(viewModel.isSubmitting || viewModel.inviteCodeField.isEmpty)

            Button("Log Out") {
                Task { await viewModel.logout() }
            }
            .font(TIAGATypography.caption)
            .foregroundStyle(TIAGAColor.textTertiary)

            Spacer()
            Spacer()
        }
        .padding(TIAGASpacing.xl)
        .background(TIAGAColor.background)
    }
}

#Preview {
    WaitlistGateView(
        viewModel: AuthViewModel(),
        account: Account(email: "waitlisted@tiaga.tech", status: .waitlisted, roles: [])
    )
}
