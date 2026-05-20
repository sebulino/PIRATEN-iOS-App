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

                // Full text body — uses displayText to skip the leading
                // `<sender>` marker the meine-piraten.de news API embeds
                // (the sender is intentionally hidden in the user-facing
                // copy per FR-NEWS / GitHub issue #67).
                //
                // SelectableTextView wraps UITextView so the body supports
                // range selection (long-press, tap to select word, drag
                // handles) and copy-to-clipboard — NFR-013. Plain
                // SwiftUI `Text` only supports full-block selection via
                // `.textSelection(.enabled)`, which is too coarse for
                // longer news bodies where users typically want to copy
                // a specific phrase or URL.
                //
                // UITextView's `dataDetectorTypes = [.link]` (set in
                // SelectableTextView) makes URLs inline-tappable too;
                // the dedicated "Links" section below remains as a
                // visible-from-the-top index for long bodies.
                SelectableTextView(
                    attributedString: nil,
                    plainText: item.displayText
                )
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)

                // Links section
                let urls = Self.detectURLs(in: item.displayText)
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
