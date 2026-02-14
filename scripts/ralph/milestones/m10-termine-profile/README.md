# Milestone 10: Termine Tab + Profile as Overlay

## Summary

Two structural UI changes to the app's main navigation:

1. **Profile → Floating Overlay**: The Profile tab is removed from the bottom tab bar and replaced with a floating icon (top-right corner) that opens the ProfileView as a sheet sliding up from the bottom. All existing profile functionality (settings, notifications, privacy) is preserved.

2. **New Termine Tab**: A new "Termine" (Events) tab replaces the Profile tab at position 4 in the bottom bar. It displays calendar events imported from the Piragitator iCal feed (`piragitator.de`).

## Tab Layout After Changes

| Index | Tab | Icon | Status |
|-------|-----|------|--------|
| 0 | Forum | bubble.left.and.bubble.right | unchanged |
| 1 | Nachrichten | envelope | unchanged |
| 2 | Wissen | book | unchanged |
| 3 | ToDos | checklist | unchanged |
| 4 | Termine | calendar | **NEW** |
| — | Profil | person.circle | **floating overlay → sheet** |

## Data Source

- **URL**: Configured via `ICAL_FEED_URL` in `.xcconfig` (not hardcoded)
- **Endpoint**: `https://piragitator.de/api/veranstaltung/ical/1/`
- **Format**: Standard iCalendar (RFC 5545)
- **Auth**: None required (public endpoint)
- **Fields used**: SUMMARY, DTSTART, DTEND, LOCATION, DESCRIPTION, CATEGORIES, URL, UID

## Architecture

Follows established project patterns (Clean Architecture + MVVM):

```
Core/Domain/Termine/
  Event.swift              — Domain entity
  EventRepository.swift    — Protocol + errors

Core/Data/Termine/
  ICalParser.swift         — RFC 5545 parser
  RealEventRepository.swift — Fetches + parses iCal feed
  FakeEventRepository.swift — Test/preview data

App/ViewModels/
  TermineViewModel.swift   — List state management

App/Views/Main/
  TermineView.swift        — Event list (ScrollView + LazyVStack)
```

## Key Decisions

- **No List view**: Uses ScrollView + LazyVStack per project convention (avoids UICollectionView dequeue crashes)
- **Inline display**: Events show all info directly in the list — no detail view navigation
- **iCal parsing**: Custom lightweight parser, no external dependencies
- **URLSession direct**: Public endpoint doesn't need the app's authenticated HTTPClient
- **Config-driven URL**: Feed URL in .xcconfig per CLAUDE.md rules

## Stories

| ID | Title |
|----|-------|
| M10-001 | Create Event domain entity and repository protocol |
| M10-002 | Implement iCal parser and event repositories |
| M10-003 | Create TermineViewModel following existing patterns |
| M10-004 | Create TermineView with inline event display |
| M10-005 | Move Profile to floating top-right icon with sheet presentation |
| M10-006 | Wire Termine tab into tab bar and update dependency chain |
