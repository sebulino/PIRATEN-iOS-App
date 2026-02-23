//
//  StartupScreenView.swift
//  PIRATEN
//
//  Created by Claude Code on 09.02.26.
//

import SwiftUI

/// The startup/splash screen shown when the app launches.
/// Displays the PIRATEN signet on an orange sunburst radial gradient background.
///
/// Privacy note: This view is purely cosmetic and collects no data.
struct StartupScreenView: View {
    /// Controls the fade-in animation of the signet
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Orange sunburst radial gradient background
            RadialGradient(
                colors: [
                    Color.piratenPrimary,
                    Color.piratenPrimary.opacity(0.99),
                    Color(red: 255/255, green: 177/255, blue: 0/255)
                ],
                center: .center,
                startRadius: 100,
                endRadius: 450
            )
            .ignoresSafeArea()

            // PIRATEN Signet - centered and animated
            Image("PiratenSignet")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.0)
        }
        .onAppear {
            // Animate the signet in with a smooth ease-out
            withAnimation(.easeOut(duration: 0.6)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    StartupScreenView()
}
