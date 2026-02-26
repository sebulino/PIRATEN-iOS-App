//
//  NewsDetailView.swift
//  PIRATEN
//

import SwiftUI

/// Detail view showing the full text of a news item with tappable URLs.
struct NewsDetailView: View {
    let item: NewsItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.postedAt, format: .dateTime.day().month(.wide).year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(item.text)
                    .font(.body)

                let urls = Self.detectURLs(in: item.text)
                if !urls.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Links")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(urls, id: \.self) { url in
                            Link(url.absoluteString, destination: url)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Detects URLs in the given text using NSDataDetector.
    static func detectURLs(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, range: range)
        return matches.compactMap { $0.url }
    }
}

#Preview {
    NavigationStack {
        NewsDetailView(item: FakeNewsRepository.sampleItems.last!)
    }
}
