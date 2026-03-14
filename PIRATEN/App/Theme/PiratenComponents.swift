//
//  PiratenComponents.swift
//  PIRATEN
//
//  Created by Claude Code on 22.02.26.
//

import CoreText
import SwiftUI
import UIKit

// MARK: - Navigation Bar Appearance

enum PiratenAppearance {
    /// Configures UIKit appearance proxies to use PoliticsHead for navigation titles
    /// and DejaRip for tab bar labels.
    /// Call once at app launch (e.g. in the App init).
    static func configure() {
        // Force-register fonts from bundle to ensure they're available early
        registerFontsIfNeeded()

        let largeTitleFont = UIFont(name: "PoliticsHead-Bold", size: 32)
            ?? UIFont.boldSystemFont(ofSize: 32)
        let inlineTitleFont = UIFont(name: "PoliticsHead-Bold", size: 18)
            ?? UIFont.boldSystemFont(ofSize: 18)

        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        let titleColor = UIColor(Color.piratenPrimary)
        navAppearance.largeTitleTextAttributes = [.font: largeTitleFont, .foregroundColor: titleColor]
        navAppearance.titleTextAttributes = [.font: inlineTitleFont, .foregroundColor: titleColor]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // Tab bar labels
        if let tabFont = UIFont(name: "DejaRip", size: 10) {
            let tabAppearance = UITabBarAppearance()
            tabAppearance.configureWithDefaultBackground()
            let itemAppearance = UITabBarItemAppearance()
            itemAppearance.normal.titleTextAttributes = [.font: tabFont]
            itemAppearance.selected.titleTextAttributes = [.font: tabFont]
            tabAppearance.stackedLayoutAppearance = itemAppearance
            tabAppearance.inlineLayoutAppearance = itemAppearance
            tabAppearance.compactInlineLayoutAppearance = itemAppearance
            UITabBar.appearance().standardAppearance = tabAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
    }

    /// Manually registers bundled font files via CoreText to ensure they're
    /// available before UIKit appearance proxies are configured.
    private static func registerFontsIfNeeded() {
        let fontFiles = [
            "PoliticsHead.otf",
            "DejaRip.otf",
            "DejaRip-Bold.otf",
            "DejaRip-Italic.otf",
            "DejaRip-BoldItalic.otf"
        ]
        for file in fontFiles {
            guard let url = Bundle.main.url(forResource: file, withExtension: nil)
                    ?? Bundle.main.url(
                        forResource: (file as NSString).deletingPathExtension,
                        withExtension: (file as NSString).pathExtension
                    )
            else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

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
/// Supports both SF Symbols (`systemName`) and custom asset images (`imageName`).
struct PiratenIconButton: View {
    let systemName: String?
    let imageName: String?
    let showBadge: Bool
    let label: String
    let onTap: () -> Void

    /// Creates a button with an SF Symbol icon.
    init(
        systemName: String,
        badge: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.imageName = nil
        self.showBadge = badge
        self.label = accessibilityLabel
        self.onTap = action
    }

    /// Creates a button with a custom asset image.
    init(
        imageName: String,
        badge: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.systemName = nil
        self.imageName = imageName
        self.showBadge = badge
        self.label = accessibilityLabel
        self.onTap = action
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack(alignment: .topTrailing) {
                iconImage
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

    @ViewBuilder
    private var iconImage: some View {
        if let systemName {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
        } else if let imageName {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
        }
    }
}
