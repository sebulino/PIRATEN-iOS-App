//
//  NewsCardView.swift
//  PIRATEN
//

import SwiftUI

/// Card component for displaying a news item in the feed.
struct NewsCardView: View {
    let item: NewsItem
    var isNew: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.headline)
                .font(.piratenSubheadline)
                .fontWeight(.bold)
                .lineLimit(2)

            Text(item.previewText)
                .font(.piratenBodyDefault)
                .lineLimit(4)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(isNew ? Color.orange.opacity(0.12) : Color.piratenSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

#Preview {
    NewsCardView(item: FakeNewsRepository.sampleItems[0])
        .padding()
}
