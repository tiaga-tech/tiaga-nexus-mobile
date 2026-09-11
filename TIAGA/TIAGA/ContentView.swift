//
//  ContentView.swift
//  TIAGA
//
//  Created by Sun Woo Kim on 11/9/2026.
//

import SwiftUI

/// The app's routing root: Login/Waitlist Gate (Section 3) or the fleet
/// console shell (Section 4) once authenticated.
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
                FleetConsoleRootView(account: account, authViewModel: authViewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TIAGAColor.background)
        .task { await authViewModel.start() }
    }
}

#Preview {
    ContentView()
}
