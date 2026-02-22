//
//  PiratenComponents.swift
//  PIRATEN
//
//  Created by Claude Code on 22.02.26.
//

import SwiftUI

// MARK: - Background Modifier

private struct PiratenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.piratenBackground.ignoresSafeArea())
    }
}

extension View {
    func piratenStyledBackground() -> some View {
        modifier(PiratenBackgroundModifier())
    }
}

// MARK: - Icon Button

/// A styled toolbar button with a rounded peach background and orange icon.
struct PiratenIconButton: View {
    let systemName: String
    let showBadge: Bool
    let label: String
    let onTap: () -> Void

    init(
        systemName: String,
        badge: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.showBadge = badge
        self.label = accessibilityLabel
        self.onTap = action
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.piratenPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.piratenIconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if showBadge {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
        }
        .accessibilityLabel(label)
    }
}
