//
//  RootView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct RootView: View {
    @ObservedObject var authStateManager: AuthStateManager

    var body: some View {
        Group {
            switch authStateManager.currentState {
            case .loggedOut, .loggingIn:
                LoginView(authStateManager: authStateManager)
            case .loggedIn:
                MainTabView()
            case .error(let message):
                ErrorView(message: message, authStateManager: authStateManager)
            }
        }
    }
}

struct ErrorView: View {
    let message: String
    @ObservedObject var authStateManager: AuthStateManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Fehler")
                .font(.title)
                .fontWeight(.bold)

            Text(message)
                .multilineTextAlignment(.center)
                .padding()

            Button("Zurück") {
                authStateManager.logout()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    RootView(authStateManager: AuthStateManager())
}
