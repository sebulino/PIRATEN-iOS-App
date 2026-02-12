//
//  MarkdownTextView.swift
//  PIRATEN
//

import SwiftUI

/// Renders markdown content using AttributedString with plain-text fallback.
struct MarkdownTextView: View {
    let markdown: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: markdown) {
            Text(attributed)
        } else {
            Text(markdown)
        }
    }
}

#Preview {
    MarkdownTextView(markdown: "**Bold** and *italic* and [link](https://example.com)")
        .padding()
}
