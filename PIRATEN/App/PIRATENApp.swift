//
//  PIRATENApp.swift
//  PIRATEN
//
//  Created by Sebulino on 29.01.26.
//

import SwiftUI

@main
struct PIRATENApp: App {
    @StateObject private var authStateManager = AuthStateManager()

    var body: some Scene {
        WindowGroup {
            RootView(authStateManager: authStateManager)
        }
    }
}
