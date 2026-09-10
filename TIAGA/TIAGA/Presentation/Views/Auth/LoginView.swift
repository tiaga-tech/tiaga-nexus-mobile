//
//  LoginView.swift
//  TIAGA
//

import SwiftUI

/// Login only — no sign-up. TIAGA accounts are created on the web today.
struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        VStack(spacing: TIAGASpacing.lg) {
            Spacer()

            Text("TIAGA")
                .font(TIAGATypography.screenTitle)
                .foregroundStyle(TIAGAColor.textPrimary)

            VStack(spacing: TIAGASpacing.md) {
                TextField(
                    "",
                    text: $viewModel.emailField,
                    prompt: Text("Email").foregroundStyle(TIAGAColor.textTertiary)
                )
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .fieldStyle()

                SecureField(
                    "",
                    text: $viewModel.passwordField,
                    prompt: Text("Password").foregroundStyle(TIAGAColor.textTertiary)
                )
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .fieldStyle()
            }

            if let message = viewModel.loginErrorMessage {
                Text(message)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.statusDanger)
                    .multilineTextAlignment(.center)
            }

            Button {
                focusedField = nil
                Task { await viewModel.submitLogin() }
            } label: {
                Text(viewModel.isSubmitting ? "Logging In…" : "Log In")
                    .font(TIAGATypography.body)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(TIAGAColor.textOnAccent)
            .padding(.vertical, TIAGASpacing.sm)
            .background(TIAGAColor.brandAccent.opacity(viewModel.isSubmitting ? 0.3 : 0.8))
            .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.md, style: .continuous))
            .disabled(viewModel.isSubmitting)

            #if DEBUG
            // Xcode-canvas-only — never shows in an actual Simulator/device run,
            // even in a DEBUG build. See ProcessInfo.isRunningInXcodePreview.
            if ProcessInfo.isRunningInXcodePreview {
                HStack(spacing: TIAGASpacing.md) {
                    Button("Fill Active Fixture") { viewModel.fillFixtureCredentials(active: true) }
                    Button("Fill Waitlisted Fixture") { viewModel.fillFixtureCredentials(active: false) }
                }
                .font(TIAGATypography.caption)
                .foregroundStyle(TIAGAColor.textTertiary)
            }
            #endif

            Spacer()
            Spacer()
        }
        .padding(TIAGASpacing.xl)
        .background(TIAGAColor.background)
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .font(TIAGATypography.body)
            .foregroundStyle(TIAGAColor.textPrimary)
            .padding(.horizontal, TIAGASpacing.md)
            .padding(.vertical, TIAGASpacing.sm)
            .background(TIAGAColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.md, style: .continuous))
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
