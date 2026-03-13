//
//  PiratenFonts.swift
//  PIRATEN
//

import SwiftUI

// MARK: - Custom Font Names

extension Font {
    /// PoliticsHead headline font at the given size.
    static func piratenHeadline(size: CGFloat) -> Font {
        .custom("PoliticsHead-Bold", size: size)
    }

    /// DejaRip body font at the given size.
    static func piratenBody(size: CGFloat) -> Font {
        .custom("DejaRip", size: size)
    }

    /// DejaRip bold body font at the given size.
    static func piratenBodyBold(size: CGFloat) -> Font {
        .custom("DejaRip-Bold", size: size)
    }

    /// DejaRip italic body font at the given size.
    static func piratenBodyItalic(size: CGFloat) -> Font {
        .custom("DejaRip-Italic", size: size)
    }
}

// MARK: - Semantic Font Styles

extension Font {
    /// Large title — PoliticsHead 32pt
    static let piratenLargeTitle: Font = .piratenHeadline(size: 32)

    /// Title — PoliticsHead 26pt
    static let piratenTitle: Font = .piratenHeadline(size: 26)

    /// Title 2 — PoliticsHead 22pt
    static let piratenTitle2: Font = .piratenHeadline(size: 22)

    /// Title 3 — PoliticsHead 20pt
    static let piratenTitle3: Font = .piratenHeadline(size: 20)

    /// Headline — DejaRip Bold 17pt
    static let piratenHeadlineBody: Font = .piratenBodyBold(size: 17)

    /// Subheadline — DejaRip 15pt
    static let piratenSubheadline: Font = .piratenBody(size: 15)

    /// Body — DejaRip 17pt
    static let piratenBodyDefault: Font = .piratenBody(size: 17)

    /// Callout — DejaRip 16pt
    static let piratenCallout: Font = .piratenBody(size: 16)

    /// Footnote — DejaRip 13pt
    static let piratenFootnote: Font = .piratenBody(size: 13)

    /// Caption — DejaRip 12pt
    static let piratenCaption: Font = .piratenBody(size: 12)

    /// Caption 2 — DejaRip 11pt
    static let piratenCaption2: Font = .piratenBody(size: 11)
}
