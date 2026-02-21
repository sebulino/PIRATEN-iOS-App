//
//  CalendarEvent.swift
//  PIRATEN
//
//  Created by Claude Code on 19.02.26.
//

import Foundation

/// Domain model representing a calendar event from the piragitator.de iCal feed.
/// Maps from VEVENT entries in the iCalendar (RFC 5545) format.
struct CalendarEvent: Identifiable, Equatable {
    /// Unique identifier (VEVENT UID)
    let id: String

    /// Event title (SUMMARY)
    let title: String

    /// Event description (DESCRIPTION), may contain HTML entities
    let description: String?

    /// Event start date/time (DTSTART)
    let startDate: Date

    /// Event end date/time (DTEND), nil for all-day single events
    let endDate: Date?

    /// Event location (LOCATION)
    let location: String?

    /// Event URL (URL)
    let url: URL?

    /// Event categories (CATEGORIES)
    let categories: [String]
}
