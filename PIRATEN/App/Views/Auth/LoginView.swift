//
//  LoginView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authStateManager: AuthStateManager
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image("PiratenSignet")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .font(.system(size: 80))
                .foregroundColor(.piratenPrimary)
                .accessibilityIdentifier("loginLogo")

            Text("PIRATEN")
                .font(.piratenLargeTitle)
                .fontWeight(.bold)
                .accessibilityIdentifier("loginTitle")

            // Text("Mitglieder-App")
            //    .font(.piratenSubheadline)
            //    .foregroundColor(.secondary)

            Spacer()

            // Show error message if authentication failed
            if case .failed(let error) = authStateManager.currentState {
                Text(error.localizedDescription)
                    .font(.piratenFootnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .accessibilityIdentifier("loginError")
            }

            if authStateManager.currentState == .authenticating {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Anmeldung wird vorbereitet...")
                    .font(.piratenFootnote)
                    .foregroundColor(.secondary)
            } else {
                Button(action: {
                    authStateManager.authenticate()
                }) {
                    Text("Mit Piratenlogin anmelden")
                        .font(.piratenHeadlineBody)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.piratenPrimary)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .accessibilityIdentifier("loginButton")
                Button(action: {
                    guard let url = URL(string: "https://members.piratenpartei.de/") else { return }
                    openURL(url)
                }) {
                    Text("Mitglied werden")
                        .font(.piratenHeadlineBody)
                        .foregroundColor(.piratenPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.piratenPrimary, lineWidth: 2)
                        )
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .accessibilityIdentifier("SignUpButton")
            }

            Spacer()
        }
        .padding()
    }
}

#Preview {
    LoginView(authStateManager: AuthStateManager(authRepository: FakeAuthRepository(credentialStore: InMemoryCredentialStore())))
}
