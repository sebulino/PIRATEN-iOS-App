//
//  CalloutView.swift
//  PIRATEN
//

import SwiftUI

/// Colored callout box for tips, warnings, and key takeaways.
struct CalloutView: View {
    let type: CalloutType
    let text: String

    private var iconName: String {
        switch type {
        case .tip: return "lightbulb.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .keyTakeaway: return "star.fill"
        }
    }

    private var title: String {
        switch type {
        case .tip: return "Tipp"
        case .warning: return "Achtung"
        case .keyTakeaway: return "Merksatz"
        }
    }

    private var accentColor: Color {
        switch type {
        case .tip: return .blue
        case .warning: return .orange
        case .keyTakeaway: return .green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundColor(accentColor)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentColor)
                MarkdownTextView(markdown: text)
                    .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentColor.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 12) {
        CalloutView(type: .tip, text: "Informiere dich vor der Sitzung über die Tagesordnung.")
        CalloutView(type: .warning, text: "Fristen für Anträge unbedingt beachten!")
        CalloutView(type: .keyTakeaway, text: "Kommunalpolitik ist die **Basis** der Demokratie.")
    }
    .padding()
}
