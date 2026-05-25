//
//  EventKitService.swift
//  PIRATEN
//
//  iOS Calendar integration for FR-EVT-003.
//  Wraps EventKit so the view layer doesn't touch EKEventStore directly
//  and so we can fake it out in tests.
//

import EventKit
import Foundation

/// Errors surfaced to the UI for the "Zu Kalender hinzufügen" flow.
/// All cases map to a single user-facing alert with German copy — the
/// raw EventKit error is not shown (and not logged, to avoid PII).
enum EventKitServiceError: Error, Equatable {
    /// User declined the permission prompt, or permission was previously
    /// denied in Settings → Datenschutz → Kalender.
    case permissionDenied
    /// The save itself failed after permission was granted (rare; usually
    /// means the system calendar database is unhealthy).
    case saveFailed
}

/// Abstraction over EventKit so views depend on a protocol, not the
/// system framework. Lets tests inject a fake without spinning up EKEventStore.
@MainActor
protocol EventKitServicing {
    /// One-shot "request permission AND save" call. The view calls this
    /// once when the user taps "Zu Kalender hinzufügen" — the service
    /// figures out whether to show the system prompt or go directly
    /// to save.
    func addToCalendar(_ event: CalendarEvent) async throws
}

/// Production implementation backed by EKEventStore.
///
/// ## Permission scope
/// We request **write-only** access (`requestWriteOnlyAccessToEvents`)
/// rather than full read+write. The app needs only the ability to add
/// events; it never reads, edits, or deletes the user's existing
/// calendar entries. Write-only is a smaller permission scope, surfaces
/// a less alarming prompt to the user, and aligns with the
/// privacy-first principle in CLAUDE.md §2.
///
/// ## Calendar selection
/// The new EKEvent is added to the user's **default calendar for new
/// events** (`store.defaultCalendarForNewEvents`). We don't pop a picker
/// — the spec is "one-tap add" (FR-EVT-003) and the default calendar is
/// what the user has already configured in iOS Settings. Power users
/// who want a different calendar can move the event in the Calendar app.
///
/// ## Duplicate protection
/// None. iOS itself does not dedupe and the spec does not require it.
/// If the user taps "Add" twice, two events appear — same behaviour as
/// every other "Add to Calendar" button in the App Store.
@MainActor
final class EventKitService: EventKitServicing {

    private let store: EKEventStore

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    func addToCalendar(_ event: CalendarEvent) async throws {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .fullAccess, .writeOnly:
            // Already granted — save immediately.
            try save(event)

        case .notDetermined:
            // First-time prompt. iOS shows the system dialog.
            let granted = try await requestWriteAccess()
            guard granted else {
                throw EventKitServiceError.permissionDenied
            }
            try save(event)

        case .denied, .restricted:
            // User previously declined or has parental restrictions.
            // Re-asking via requestWriteOnlyAccessToEvents would not
            // re-prompt — iOS just returns the cached denial. The view
            // surfaces this as "öffne Einstellungen → Datenschutz".
            throw EventKitServiceError.permissionDenied

        @unknown default:
            // Future EventKit cases — treat as denied so we never
            // silently fail.
            throw EventKitServiceError.permissionDenied
        }
    }

    // MARK: - Private

    private func requestWriteAccess() async throws -> Bool {
        // requestWriteOnlyAccessToEvents was added in iOS 17 and is the
        // recommended API for apps that only need to write. iOS 26.2
        // deployment target means we can use it without availability checks.
        try await store.requestWriteOnlyAccessToEvents()
    }

    private func save(_ event: CalendarEvent) throws {
        let ekEvent = EKEvent(eventStore: store)
        ekEvent.title = event.title
        ekEvent.startDate = event.startDate
        // EKEvent requires an end date. If the source had none (single
        // all-day events from iCal don't always carry DTEND), default
        // to a 1-hour window starting at the published start time —
        // matches the convention iOS Calendar uses when the user
        // creates a new event from scratch.
        ekEvent.endDate = event.endDate ?? event.startDate.addingTimeInterval(3600)
        if let location = event.location, !location.isEmpty {
            ekEvent.location = location
        }
        if let description = event.description, !description.isEmpty {
            ekEvent.notes = description
        }
        if let url = event.url {
            ekEvent.url = url
        }
        ekEvent.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(ekEvent, span: .thisEvent)
        } catch {
            throw EventKitServiceError.saveFailed
        }
    }
}
