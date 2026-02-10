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

            Image("PiratenSignet")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .font(.system(size: 80))
                .foregroundColor(.orange)
                .accessibilityIdentifier("loginLogo")

            Text("PIRATEN")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityIdentifier("loginTitle")

            // Text("Mitglieder-App")
            //    .font(.subheadline)
            //    .foregroundColor(.secondary)

            Spacer()

            // Show error message if authentication failed
            if case .failed(let error) = authStateManager.currentState {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .accessibilityIdentifier("loginError")
            }

            if authStateManager.currentState == .authenticating {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Anmeldung wird vorbereitet...")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Button(action: {
                    authStateManager.authenticate()
                }) {
                    Text("Mit Piratenlogin anmelden")
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
