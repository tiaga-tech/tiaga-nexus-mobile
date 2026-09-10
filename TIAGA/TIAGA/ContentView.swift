//
//  ContentView.swift
//  TIAGA
//
//  Created by Sun Woo Kim on 11/9/2026.
//

import SwiftUI

/// The app's routing root. Section 4 (Side Menu) will replace the
/// `.authenticated` destination with the real fleet-console shell — for now
/// it's a temporary placeholder so the auth flow is fully closeable
/// (log in → log out → back to Login) for manual testing.
struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            switch authViewModel.route {
            case .checkingSession:
                ProgressView()
                    .tint(TIAGAColor.brandAccent)
            case .login:
                LoginView(viewModel: authViewModel)
            case .waitlistGate(let account):
                WaitlistGateView(viewModel: authViewModel, account: account)
            case .authenticated(let account):
                AuthenticatedPlaceholderView(account: account, viewModel: authViewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TIAGAColor.background)
        .task { await authViewModel.start() }
    }
}

/// Temporary stand-in for the Section 4 fleet-console shell — exists only so
/// the auth flow has somewhere to land and a way back to Login for testing.
private struct AuthenticatedPlaceholderView: View {
    let account: Account
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: TIAGASpacing.lg) {
            Text("Welcome, \(account.email)")
                .font(TIAGATypography.headline)
                .foregroundStyle(TIAGAColor.textPrimary)
            Text("(Section 4 replaces this with the fleet console)")
                .font(TIAGATypography.caption)
                .foregroundStyle(TIAGAColor.textTertiary)
            Button("Log Out") {
                Task { await viewModel.logout() }
            }
            .font(TIAGATypography.body)
            .foregroundStyle(TIAGAColor.brandAccent)
        }
        .padding(TIAGASpacing.xl)
    }
}

#Preview {
    ContentView()
}
