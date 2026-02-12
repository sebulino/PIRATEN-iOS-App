//
//  SectionCard.swift
//  PIRATEN
//

import SwiftUI

/// Accordion card that expands/collapses with spring animation.
/// Default state is collapsed.
struct SectionCard<Content: View>: View {
    let heading: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(heading)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.3), value: isExpanded)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(heading), \(isExpanded ? "eingeklappt" : "ausgeklappt")")
            .accessibilityHint("Doppeltippen zum \(isExpanded ? "Einklappen" : "Ausklappen")")

            if isExpanded {
                content()
                    .padding([.horizontal, .bottom])
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    SectionCard(
        heading: "Was ist Kommunalpolitik?",
        isExpanded: true,
        onToggle: {}
    ) {
        Text("Kommunalpolitik umfasst die politischen Entscheidungen auf Gemeinde- und Kreisebene.")
    }
    .padding()
}
