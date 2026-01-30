//
//  PIRATENApp.swift
//  PIRATEN
//
//  Created by Sebulino on 29.01.26.
//

import SwiftUI

@main
struct PIRATENApp: App {
    /// The central dependency container for the application.
    /// All dependencies are constructed here and injected into the view hierarchy.
    private let container: AppContainer

    init() {
        self.container = AppContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authStateManager: container.authStateManager,
                forumViewModel: container.forumViewModel,
                todosViewModel: container.todosViewModel,
                profileViewModel: container.profileViewModel
            )
        }
    }
}
