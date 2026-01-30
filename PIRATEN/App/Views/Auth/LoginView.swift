//
//  LoginView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authStateManager: AuthStateManager

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "flag.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
                .accessibilityIdentifier("loginLogo")

            Text("PIRATEN")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityIdentifier("loginTitle")

            Text("Mitglieder-App")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            if authStateManager.currentState == .authenticating {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                Button(action: {
                    authStateManager.authenticate()
                }) {
                    Text("Anmelden (Fake)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .accessibilityIdentifier("loginButton")
            }

            Spacer()
        }
        .padding()
    }
}

#Preview {
    LoginView(authStateManager: AuthStateManager(authRepository: FakeAuthRepository(credentialStore: InMemoryCredentialStore())))
}
