//
//  CalendarView.swift
//  PIRATEN
//
//  Created by Claude Code on 19.02.26.
//

import SwiftUI

struct CalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel

    /// Callback when user taps the profile toolbar button
    var onProfileTapped: (() -> Void)?

    /// Callback when user taps the notifications toolbar button
    var onNotificationsTapped: (() -> Void)?

    /// Whether to show a badge on the notification bell
    var notificationsBadge: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    if viewModel.events.isEmpty {
                        ProgressView("Lade Termine...")
                    } else {
                        eventContent
                    }

                case .loaded:
                    if viewModel.events.isEmpty {
                        emptyState
                    } else {
                        eventContent
                    }

                case .error(let message):
                    errorState(message: message)
                }
            }
            .navigationTitle("Termine")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        onNotificationsTapped?()
                    } label: {
                        Image(systemName: notificationsBadge ? "bell.badge" : "bell")
                    }
                    .accessibilityLabel("Benachrichtigungen")

                    Button {
                        onProfileTapped?()
                    } label: {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityLabel("Profil")
                }
            }
            .onAppear {
                if viewModel.loadState == .idle {
                    viewModel.loadEvents()
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var eventContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !viewModel.upcomingEvents.isEmpty {
                    Section {
                        ForEach(viewModel.upcomingEvents) { event in
                            CalendarEventRow(event: event)
                        }
                    } header: {
                        Text("Kommende Termine")
                            .font(.headline)
                            .padding(.top, 8)
                    }
                }

                if !viewModel.pastWeekEvents.isEmpty {
                    Section {
                        ForEach(viewModel.pastWeekEvents) { event in
                            CalendarEventRow(event: event)
                                .opacity(0.7)
                        }
                    } header: {
                        Text("Vergangene Woche")
                            .font(.headline)
                            .padding(.top, 8)
                    }
                }

                if viewModel.upcomingEvents.isEmpty && viewModel.pastWeekEvents.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    // MARK: - State Views

    private var emptyState: some View {
        ContentUnavailableView(
            "Keine Termine",
            systemImage: "calendar",
            description: Text("Aktuell sind keine Termine verfügbar.")
        )
    }

    @ViewBuilder
    private func errorState(message: String) -> some View {
        ContentUnavailableView {
            Label("Fehler", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Erneut versuchen") {
                viewModel.refresh()
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - CalendarEventRow

private struct CalendarEventRow: View {
    let event: CalendarEvent

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let location = event.location, !location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            if !event.categories.isEmpty {
                HStack(spacing: 4) {
                    ForEach(event.categories, id: \.self) { category in
                        Text(category)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedDate: String {
        // Check if this is an all-day event (midnight to midnight or no end date with midnight start)
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: event.startDate)
        let isAllDay = startComponents.hour == 0 && startComponents.minute == 0

        if isAllDay {
            return Self.dateOnlyFormatter.string(from: event.startDate)
        }
        return Self.dateFormatter.string(from: event.startDate)
    }
}

#Preview {
    CalendarView(
        viewModel: CalendarViewModel(calendarRepository: FakeCalendarRepository())
    )
}
