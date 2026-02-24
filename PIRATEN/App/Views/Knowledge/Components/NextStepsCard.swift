//
//  NextStepsCard.swift
//  PIRATEN
//

import SwiftUI

/// Shows links to related topics as next reading suggestions.
struct NextStepsCard: View {
    let topicIds: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Nächste Schritte", systemImage: "arrow.right.circle.fill")
                .font(.headline)
                .foregroundColor(.piratenPrimary)

            ForEach(topicIds, id: \.self) { topicId in
                HStack(spacing: 8) {
                    Image(systemName: "book")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Text(topicId)
                        .font(.subheadline)
                        .foregroundColor(.primary)
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
    NextStepsCard(topicIds: [
        "kommunalpolitik-basics",
        "antragsformulierung",
        "haushalt-lesen"
    ])
    .padding()
}
