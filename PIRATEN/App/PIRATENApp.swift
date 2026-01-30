//
//  PIRATENApp.swift
//  PIRATEN
//
//  Created by Sebulino on 29.01.26.
//

import SwiftUI

@main
struct PIRATENApp: App {
    @StateObject private var authStateManager: AuthStateManager

    init() {
        // Composition root: wire up dependencies here
        let authRepository = FakeAuthRepository()
        _authStateManager = StateObject(wrappedValue: AuthStateManager(authRepository: authRepository))
    }

    var body: some Scene {
        WindowGroup {
            RootView(authStateManager: authStateManager)
        }
    }
}
