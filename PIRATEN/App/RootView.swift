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
            case .unauthenticated, .authenticating:
                LoginView(authStateManager: authStateManager)
            case .authenticated:
                MainTabView()
            case .failed(let error):
                ErrorView(error: error, authStateManager: authStateManager)
            }
        }
    }
}

struct ErrorView: View {
    let error: AuthError
    @ObservedObject var authStateManager: AuthStateManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Fehler")
                .font(.title)
                .fontWeight(.bold)

            Text(error.localizedDescription)
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
    RootView(authStateManager: AuthStateManager(authRepository: FakeAuthRepository(credentialStore: InMemoryCredentialStore())))
}
