//
//  ICalParserTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 19.02.26.
//

import Foundation
import Testing
@testable import PIRATEN

@Suite("ICalParser Tests")
struct ICalParserTests {

    let parser = ICalParser()

    // MARK: - Valid Parsing

    @Test("Parses a valid VCALENDAR with one event")
    func parseValidCalendar() {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        UID:event-1@piragitator.de
        SUMMARY:Landesparteitag
        DTSTART:20260315T140000
        DTEND:20260315T180000
        LOCATION:Dortmund
        CATEGORIES:Parteitag,NRW
        END:VEVENT
        END:VCALENDAR
        """

        let events = parser.parse(ical)
        #expect(events.count == 1)

        let event = events[0]
        #expect(event.id == "event-1@piragitator.de")
        #expect(event.title == "Landesparteitag")
        #expect(event.location == "Dortmund")
        #expect(event.categories == ["Parteitag", "NRW"])
        #expect(event.endDate != nil)
    }

    @Test("Parses multiple events")
    func parseMultipleEvents() {
        let ical = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:event-1
        SUMMARY:Event One
        DTSTART:20260315T140000
        END:VEVENT
        BEGIN:VEVENT
        UID:event-2
        SUMMARY:Event Two
        DTSTART:20260316T100000
        END:VEVENT
        END:VCALENDAR
        """

        let events = parser.parse(ical)
        #expect(events.count == 2)
        #expect(events[0].title == "Event One")
        #expect(events[1].title == "Event Two")
    }

    // MARK: - Date Format Tests

    @Test("Parses date-only format (yyyyMMdd)")
    func parseDateOnly() {
        let ical = """
        BEGIN:VEVENT
        UID:allday-1
        SUMMARY:All Day Event
        DTSTART;VALUE=DATE:20260401
        DTEND;VALUE=DATE:20260402
        END:VEVENT
        """

        let events = parser.parse(ical)
        #expect(events.count == 1)
        #expect(events[0].endDate != nil)
    }

    @Test("Parses UTC date-time with Z suffix")
    func parseUTCDateTime() {
        let ical = """
        BEGIN:VEVENT
        UID:utc-1
        SUMMARY:UTC Event
        DTSTART:20260315T120000Z
        END:VEVENT
        """

        let events = parser.parse(ical)
        #expect(events.count == 1)
    }

    // MARK: - Line Unfolding

    @Test("Handles RFC 5545 line unfolding (continuation lines)")
    func lineUnfolding() {
        // Lines starting with a space are continuations of the previous line
        let ical = "BEGIN:VEVENT\r\nUID:fold-1\r\nSUMMARY:This is a very\r\n  long summary\r\nDTSTART:20260315T140000\r\nEND:VEVENT"

        let events = parser.parse(ical)
        #expect(events.count == 1)
        #expect(events[0].title == "This is a very long summary")
    }

    // MARK: - Missing Fields

    @Test("Skips events missing UID")
    func skipsMissingUID() {
        let ical = """
        BEGIN:VEVENT
        SUMMARY:No UID Event
        DTSTART:20260315T140000
        END:VEVENT
        """

        let events = parser.parse(ical)
        #expect(events.isEmpty)
    }

    @Test("Skips events missing DTSTART")
    func skipsMissingDTSTART() {
        let ical = """
        BEGIN:VEVENT
        UID:no-start
        SUMMARY:No Start Event
        END:VEVENT
        """

        let events = parser.parse(ical)
        #expect(events.isEmpty)
    }

    @Test("Event without SUMMARY uses UID as title")
    func missingGracefully() {
        let ical = """
        BEGIN:VEVENT
        UID:no-summary
        DTSTART:20260315T140000
        END:VEVENT
        """

        let events = parser.parse(ical)
        #expect(events.count == 1)
        #expect(events[0].title == "no-summary")
        #expect(events[0].location == nil)
        #expect(events[0].description == nil)
        #expect(events[0].categories.isEmpty)
    }

    // MARK: - Malformed Input

    @Test("Returns empty array for completely invalid input")
    func malformedInput() {
        let events = parser.parse("This is not iCal data at all")
        #expect(events.isEmpty)
    }

    @Test("Returns empty array for empty input")
    func emptyInput() {
        let events = parser.parse("")
        #expect(events.isEmpty)
    }

    // MARK: - Text Unescaping

    @Test("Unescapes iCal text values")
    func textUnescaping() {
        let ical = """
        BEGIN:VEVENT
        UID:escape-1
        SUMMARY:Hello\\, World
        DESCRIPTION:Line one\\nLine two
        DTSTART:20260315T140000
        END:VEVENT
        """

        let events = parser.parse(ical)
        #expect(events.count == 1)
        #expect(events[0].title == "Hello, World")
        #expect(events[0].description == "Line one\nLine two")
    }

    // MARK: - URL Parsing

    @Test("Parses event URL")
    func parseURL() {
        let ical = """
        BEGIN:VEVENT
        UID:url-1
        SUMMARY:Event with URL
        DTSTART:20260315T140000
        URL:https://piragitator.de/event/1/
        END:VEVENT
        """

        let events = parser.parse(ical)
        #expect(events.count == 1)
        #expect(events[0].url?.absoluteString == "https://piragitator.de/event/1/")
    }
}
