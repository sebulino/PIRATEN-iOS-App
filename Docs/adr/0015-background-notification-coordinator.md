# ADR-0015 — Per-source background notification dispatch via plain-object coordinator

- **Status:** Accepted
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** FR-NOTIF-003, FR-NOTIF-004, FR-PROF-002, ADR-0006, OPEN-12 (#75)

## Context

[ADR-0006](./0006-notifications-v1-polling.md) committed v1 to client-side
polling instead of APNs push. That ADR introduced two mechanisms:

- A foreground `Timer` cycle in `MainTabView` polling for fresh content.
- A `BGAppRefreshTask` for headless polling while the app is suspended.

In practice the background path did not deliver notifications.

Two compounding defects:

1. **Aggregate-only polling.** The background handler only called
   Discourse's `/notifications/totals.json`, an aggregate-unread endpoint.
   It could not tell Forum from Messages, and Todos/News/Knowledge/Events
   were never polled at all. An app closed for days would not notice new
   todos, news, calendar events, or Kanon updates.

2. **View-bound dispatch.** The code that actually called
   `UNUserNotificationCenter.add(...)` lived inside SwiftUI `.onChange`
   observers in `MainTabView`. Those observers only run while the view
   is rendered. When iOS wakes the app headless for a `BGAppRefreshTask`,
   no view hierarchy exists. The observers never fire. The user receives
   no banner regardless of category settings.

The second defect is OPEN-12 — a hard v1 blocker (FR-NOTIF-004 promises
local notifications dispatch when the background task detects new
content). Solving (2) without also solving (1) would only let
notifications fire for Discourse aggregate counts; the four other
content sources would stay invisible in the background.

Three alternatives were weighed:

- **Move dispatch into the BGAppRefreshTask handler, keep aggregate
  polling.** Cheapest. Closes OPEN-12 for Messages/Forum but leaves
  Todos, News, Knowledge, Events undetected in the background. Fails
  FR-NOTIF-003.

- **Per-source polling + dispatch in the handler.** Higher initial cost
  (six requests per wake-up instead of one), correct per the spec.
  Discourse's rate budget is 20 requests/minute; six over a 30-minute
  cadence is fine. Closes OPEN-12 and FR-NOTIF-003.

- **Reintroduce APNs.** Would solve both defects elegantly but
  re-opens the server-side dependency that [ADR-0006](./0006-notifications-v1-polling.md)
  was specifically built to avoid (no Discourse webhook story).

The middle option was chosen.

## Decision

**Introduce a plain-object `BackgroundRefreshCoordinator` invoked from
`BGAppRefreshTask.handleAppRefresh`.** Polls all six volatile sources
(Forum, Messages, Todos, News, Knowledge, Events) in parallel via a
`TaskGroup`. Each child has its own `do/catch`; one source failing does
not abort the siblings. For each source with new activity since the
last wake-up, the coordinator consults `NotificationSettingsManager` for
the per-category toggle (FR-PROF-002), and on `enabled == true`
schedules a `UNMutableNotificationContent` via a shared
`LocalNotificationScheduler`.

Three structural pieces:

- **`PIRATEN/Core/Data/Notifications/BackgroundRefreshCoordinator.swift`**
  — the new coordinator. Plain `@MainActor` final class. Holds references
  to the six repositories + `AuthRepository` + `NotificationSettingsManager`
  + scheduler. Owns persisted `bg_*_last_seen_*` UserDefaults keys,
  deliberately separate from the foreground ViewModels' own
  `forum_last_seen_topic_id` / etc. keys so the two paths never clobber
  each other's state.

- **`PIRATEN/Core/Data/Notifications/LocalNotificationScheduler.swift`**
  — single dispatch helper used by both the headless coordinator and
  the foreground `.onChange` observers. The six fixed German title +
  body strings live on a `NotificationCategory` enum so foreground and
  background notifications are visually identical.

- **`NotificationSettingsManager`** — extended with `knowledgeEnabled`
  and `eventsEnabled` to reach the six categories FR-PROF-002 specifies.
  The existing four toggles (Messages, Forum, Todos, News) are unchanged.

The `BackgroundTaskScheduler.handleAppRefresh` now runs the coordinator
before the existing aggregate-totals badge update. Both run inside a
single `Task` whose handle is captured so iOS's expiration callback can
cancel cleanly.

The foreground `.onChange` observers in `MainTabView` are kept but
re-routed through the shared scheduler via a thin
`dispatchLocalNotification(_ category:)` helper. This gives zero-latency
banners while the app is open while keeping one source of truth for
notification content. Two new observers added for Knowledge and Events
to reach parity with the six-category background coordinator.

## Consequences

- **Positive.** OPEN-12 closes. FR-NOTIF-003 and FR-NOTIF-004 are now
  satisfied. The fix is testable headless: the coordinator runs without
  any view hierarchy and can be exercised by simulating a
  `BGAppRefreshTask` fire with fake repositories.
- **Positive.** Per-source persistence in `bg_*_last_seen_*` means
  flipping a category toggle on later does not flood the user with
  everything that accumulated while it was off — the marker is updated
  on every poll, the dispatch is gated on the toggle. A category that
  was disabled then enabled starts emitting notifications only for
  truly new activity.
- **Negative.** Six background polls per `BGAppRefreshTask` wake-up
  instead of one. iOS throttles the cadence at the task level, not
  per-request, so this fits the rate budget. The Knowledge poll uses
  the GitHub Contents API which is conditional-GETable; with no
  changes upstream it costs effectively zero. The other five poll
  full lists by default — a future optimisation could expose
  "summary" endpoints if any source proves expensive.
- **Negative.** `DiscourseNotificationPoller` (the aggregate-totals
  badge updater that pre-dated the coordinator) is still called from
  the same `BGAppRefreshTask` for badge-count maths. The two now have
  overlapping but disjoint responsibilities: the coordinator owns
  per-category notification dispatch, the poller owns the iOS home-
  screen badge count. Folding them is deferred until the badge math
  itself needs to change.
- **Follow-ups.**
  - On logout, `BackgroundRefreshCoordinator.reset()` must be invoked
    alongside `DiscourseNotificationPoller.reset()` so the next login
    does not fire notifications for everything accumulated since
    logout. Wire-up tracked as a small follow-up commit.
  - End-to-end verification on a real device (TestFlight) is required
    before claiming OPEN-12 closed — the simulator's `simctl push`
    path is not equivalent to a real `BGAppRefreshTask` fire.
