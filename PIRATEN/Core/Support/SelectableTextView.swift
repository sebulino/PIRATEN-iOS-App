//
//  SelectableTextView.swift
//  PIRATEN
//
//  Created by Claude Code on 16.03.26.
//

import SwiftUI
import UIKit

/// A UITextView wrapper that supports partial text selection (range selection)
/// in SwiftUI. SwiftUI's `.textSelection(.enabled)` only allows full-block
/// selection, so we use UIKit's UITextView for true range selection.
struct SelectableTextView: UIViewRepresentable {
    let attributedString: AttributedString?
    let plainText: String?
    let font: UIFont

    init(attributedString: AttributedString?, plainText: String? = nil, font: UIFont = .preferredFont(forTextStyle: .body)) {
        self.attributedString = attributedString
        self.plainText = plainText
        self.font = font
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = [.link]
        textView.linkTextAttributes = [.foregroundColor: UIColor.tintColor]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if let attributedString {
            let nsAttrString = NSMutableAttributedString(attributedString)
            // Ensure the font is applied as a base
            nsAttrString.addAttribute(.font, value: font, range: NSRange(location: 0, length: nsAttrString.length))
            textView.attributedText = nsAttrString
        } else if let plainText {
            textView.text = plainText
            textView.font = font
        }
        textView.textColor = .label
        // Invalidate intrinsic content size so SwiftUI recalculates layout
        textView.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.superview?.bounds.width ?? 300
        let fittingSize = uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: width, height: fittingSize.height)
    }
}
