//
//  CalendarEventDetailView.swift
//  PIRATEN
//
//  Detail view for a calendar event with the "Zu Kalender hinzufügen"
//  action (FR-EVT-003).
//

import SwiftUI
import UIKit

/// Full-screen detail for a single CalendarEvent. Surfaces the event's
/// title, date range, location, description, optional external URL,
/// categories — plus the "Zu Kalender hinzufügen" action that hands
/// off to EventKit.
struct CalendarEventDetailView: View {

    let event: CalendarEvent
    let eventKitService: EventKitServicing

    @State private var isAdding = false
    @State private var alert: AddToCalendarAlert?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                Divider().padding(.horizontal, 16)

                detailSection

                addButton
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
        }
        .piratenStyledBackground()
        .navigationTitle("Termin")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $alert) { kind in
            switch kind {
            case .success:
                return Alert(
                    title: Text("Hinzugefügt"),
                    message: Text("Termin wurde dem Kalender hinzugefügt."),
                    dismissButton: .default(Text("OK"))
                )
            case .permissionDenied:
                return Alert(
                    title: Text("Berechtigung benötigt"),
                    message: Text("Erlaube den Kalender-Zugriff in den Einstellungen unter Datenschutz → Kalender, um Termine hinzuzufügen."),
                    primaryButton: .default(Text("Einstellungen"), action: openSettings),
                    secondaryButton: .cancel(Text("Abbrechen"))
                )
            case .saveFailed:
                return Alert(
                    title: Text("Fehler"),
                    message: Text("Termin konnte nicht zum Kalender hinzugefügt werden. Bitte versuche es erneut."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !event.categories.isEmpty {
                HStack(spacing: 6) {
                    ForEach(event.categories, id: \.self) { category in
                        Text(category)
                            .font(.piratenCaption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }

            Text(event.title)
                .font(.piratenTitle3)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Details

    @ViewBuilder
    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            row(icon: "calendar", text: formattedDateRange)

            if let location = event.location, !location.isEmpty {
                row(icon: "mappin.and.ellipse", text: location)
            }

            if let description = event.description, !description.isEmpty {
                Text(description)
                    .font(.piratenBodyDefault)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let url = event.url {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.piratenSubheadline)
                        Text(url.host ?? url.absoluteString)
                            .font(.piratenSubheadline)
                            .underline()
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func row(icon: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.piratenSubheadline)
                .foregroundColor(.secondary)
                .frame(width: 18)
            Text(text)
                .font(.piratenBodyDefault)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Add button

    private var addButton: some View {
        Button(action: addToCalendar) {
            HStack {
                if isAdding {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "calendar.badge.plus")
                }
                Text("Zu Kalender hinzufügen")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isAdding)
        .accessibilityLabel("Termin zum Kalender hinzufügen")
    }

    // MARK: - Actions

    private func addToCalendar() {
        guard !isAdding else { return }
        isAdding = true
        Task { @MainActor in
            defer { isAdding = false }
            do {
                try await eventKitService.addToCalendar(event)
                alert = .success
            } catch EventKitServiceError.permissionDenied {
                alert = .permissionDenied
            } catch {
                alert = .saveFailed
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Formatting

    private var formattedDateRange: String {
        let calendar = Calendar.current
        let isAllDay = calendar.component(.hour, from: event.startDate) == 0
            && calendar.component(.minute, from: event.startDate) == 0

        let style = Date.FormatStyle()
            .locale(Locale(identifier: "de_DE"))
            .day().month(.wide).year()
            .weekday(.wide)

        let dateOnly = event.startDate.formatted(style)

        if isAllDay {
            return dateOnly
        }

        let time = event.startDate.formatted(date: .omitted, time: .shortened)
        if let end = event.endDate {
            let endTime = end.formatted(date: .omitted, time: .shortened)
            return "\(dateOnly), \(time) – \(endTime)"
        }
        return "\(dateOnly), \(time)"
    }
}

// MARK: - Alert state

private enum AddToCalendarAlert: Identifiable {
    case success
    case permissionDenied
    case saveFailed

    var id: Int {
        switch self {
        case .success: return 1
        case .permissionDenied: return 2
        case .saveFailed: return 3
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CalendarEventDetailView(
            event: CalendarEvent(
                id: "preview-1",
                title: "Stammtisch Berlin",
                description: "Monatlicher Stammtisch im Pirate-Café. Wir besprechen kommende Aktionen und tauschen uns aus.",
                startDate: Date().addingTimeInterval(86400 * 3 + 3600 * 19),
                endDate: Date().addingTimeInterval(86400 * 3 + 3600 * 22),
                location: "Pirate-Café, Mainzer Str. 11, Berlin",
                url: URL(string: "https://agitatorrr.de/event/123"),
                categories: ["Berlin", "Stammtisch"]
            ),
            eventKitService: PreviewEventKitService()
        )
    }
}

@MainActor
private struct PreviewEventKitService: EventKitServicing {
    func addToCalendar(_ event: CalendarEvent) async throws {
        // No-op for preview.
    }
}
