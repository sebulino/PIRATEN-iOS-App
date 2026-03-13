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
            VStack(alignment: .leading, spacing: 0) {
                // Header with date and headline
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(item.postedAt, format: .dateTime.day().month(.wide).year())
                            .font(.piratenSubheadline)
                    } icon: {
                        Image(systemName: "calendar")
                            .font(.piratenSubheadline)
                    }
                    .foregroundStyle(.secondary)

                    Text(item.headline)
                        .font(.piratenTitle3)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()
                    .padding(.horizontal, 16)

                // Full text body
                Text(item.text)
                    .font(.piratenBodyDefault)
                    .lineSpacing(4)
                    .padding(16)

                // Links section
                let urls = Self.detectURLs(in: item.text)
                if !urls.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Links", systemImage: "link")
                            .font(.piratenSubheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        ForEach(urls, id: \.self) { url in
                            Link(destination: url) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.piratenSubheadline)
                                    Text(Self.displayHost(for: url))
                                        .font(.piratenSubheadline)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.piratenSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .piratenStyledBackground()
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

    /// Returns a readable display string for a URL (host + path).
    static func displayHost(for url: URL) -> String {
        var display = url.host ?? url.absoluteString
        let path = url.path
        if !path.isEmpty && path != "/" {
            display += path
        }
        return display
    }
}

#Preview("With links") {
    NavigationStack {
        NewsDetailView(item: FakeNewsRepository.sampleItems.last!)
    }
}

#Preview("Plain text") {
    NavigationStack {
        NewsDetailView(item: FakeNewsRepository.sampleItems.first!)
    }
}
