//
//  TIAGAApp.swift
//  TIAGA
//
//  Created by Sun Woo Kim on 11/9/2026.
//

import SwiftUI

@main
struct TIAGAApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // TIAGA's visual identity is dark-only (see TIAGAColor) — force it
                // regardless of the device's system appearance setting.
                .preferredColorScheme(.dark)
        }
    }
}
