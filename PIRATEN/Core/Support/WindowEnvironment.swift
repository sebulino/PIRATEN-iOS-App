//
//  WindowEnvironment.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import SwiftUI
import UIKit

/// Environment key for accessing the current UIWindow.
/// Used for presenting ASWebAuthenticationSession.
private struct WindowKey: EnvironmentKey {
    static let defaultValue: UIWindow? = nil
}

extension EnvironmentValues {
    /// The current UIWindow, if available.
    var window: UIWindow? {
        get { self[WindowKey.self] }
        set { self[WindowKey.self] = newValue }
    }
}

/// A view modifier that injects the current UIWindow into the environment.
struct WindowProvider: ViewModifier {
    @State private var window: UIWindow?

    func body(content: Content) -> some View {
        content
            .environment(\.window, window)
            .background(WindowReader(window: $window))
    }
}

/// A UIViewRepresentable that reads the current window.
private struct WindowReader: UIViewRepresentable {
    @Binding var window: UIWindow?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if self.window != uiView.window {
                self.window = uiView.window
            }
        }
    }
}

extension View {
    /// Provides the current UIWindow to descendant views via the environment.
    func provideWindow() -> some View {
        modifier(WindowProvider())
    }
}
