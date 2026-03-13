//
//  OverviewCard.swift
//  PIRATEN
//

import SwiftUI

/// Always-visible card showing overview bullets (Kurzüberblick).
struct OverviewCard: View {
    let bullets: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Kurzüberblick", systemImage: "list.bullet")
                .font(.piratenHeadlineBody)
                .foregroundColor(.piratenPrimary)

            ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.piratenPrimary)
                    MarkdownTextView(markdown: bullet)
                        .font(.piratenSubheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    OverviewCard(bullets: [
        "Erster Punkt mit **wichtigem** Inhalt",
        "Zweiter Punkt zum Thema",
        "Dritter Punkt mit Details"
    ])
    .padding()
}
