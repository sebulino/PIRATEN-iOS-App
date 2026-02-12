//
//  ChecklistCard.swift
//  PIRATEN
//

import SwiftUI

/// Interactive checklist with toggle callbacks and progress label.
struct ChecklistCard: View {
    let items: [ChecklistItem]
    let isCompleted: (UUID) -> Bool
    let onToggle: (UUID) -> Void

    private var completedCount: Int {
        items.filter { isCompleted($0.id) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Checkliste", systemImage: "checklist")
                    .font(.headline)
                    .foregroundColor(.orange)
                Spacer()
                Text("\(completedCount)/\(items.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(items) { item in
                Button {
                    onToggle(item.id)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: isCompleted(item.id) ? "checkmark.square.fill" : "square")
                            .foregroundColor(isCompleted(item.id) ? .orange : .secondary)
                            .font(.title3)
                        Text(item.text)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .strikethrough(isCompleted(item.id))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.text), \(isCompleted(item.id) ? "erledigt" : "offen")")
                .accessibilityHint("Doppeltippen zum Umschalten")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ChecklistCard(
        items: [
            ChecklistItem(id: UUID(), text: "Gemeinderat besuchen"),
            ChecklistItem(id: UUID(), text: "Antrag formulieren"),
            ChecklistItem(id: UUID(), text: "Unterschriften sammeln")
        ],
        isCompleted: { _ in false },
        onToggle: { _ in }
    )
    .padding()
}
