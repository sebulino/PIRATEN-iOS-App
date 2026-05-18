# ADR-0006 — Polling-based notifications with local banner dispatch

- **Status:** Accepted
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** FR-NOTIF-*, ADR-0004, OPEN-12

## Context

Users expect messenger-style awareness of new activity without opening the
app. A pure push-notification system would require three pieces the project
does not have:

1. A server component authorised to call APNs with per-device tokens.
2. Per-user device registration, keyed to the PiratenSSO identity.
3. A policy for what goes into a push payload without leaking content.

Discourse itself does not push to third-party mobile apps for us; its
built-in push is for browsers and the official Discourse Hub app.

Shipping a push relay service contradicts [ADR-0004](./0004-no-app-specific-backend-v1.md)
for v1. `meine-piraten.de` exposes a `/api/push_subscriptions` endpoint,
but it is designed for its own APNs relay and does not cover Discourse
notifications (forum, PMs) — which are the dominant source of new activity.

## Decision

**v1 uses client-side polling with local iOS notifications.**

**Foreground polling.** While the app is in the foreground, a
`NotificationPoller` queries Discourse's `/notifications/totals.json` every
60 seconds (backoff on error, stop when backgrounded) and updates tab-bar
badges and the Kajüte.

**Background polling.** A `BGAppRefreshTask` is scheduled for a 30-minute
cadence. When it fires, it polls **six volatile sources** independently:

1. Forum activity (Discourse)
2. Private messages (Discourse)
3. News (meine-piraten.de)
4. ToDos (meine-piraten.de)
5. Knowledge / Kanon (GitHub commit SHA check)
6. Events / Calendar (Agitatorrr iCal)

A failure in one source does not block the others.

**Local notification dispatch.** When the background task finds new activity
in a category for which the user has enabled notifications (FR-PROF-002),
it schedules a **local iOS notification** (`UNMutableNotificationContent`,
banner + sound) via `UNUserNotificationCenter.current().add(...)`.

No APNs push notifications, no remote notification payloads, no push relay.

## Consequences

- **Positive.** The app ships without operating a backend. The user gets
  banner notifications on the lock screen for the activity categories they
  care about, subject to iOS's own scheduling of background refresh.
- **Negative.** Cadence is controlled by iOS, not by us — the 30-minute
  request is a hint, not a guarantee. Users who disable Background App
  Refresh at the iOS level receive no background updates at all. This is
  honestly surfaced in the Profil screen's notification settings copy.
- **Cost control.** Poll cadence, backoff and foreground-only foreground
  gating keep Discourse load bounded. The HTTP client's per-host concurrency
  cap prevents thundering herds after app foregrounding.
- **Known gap (OPEN-12).** Today the code dispatches local notifications
  only from SwiftUI `.onChange` observers, which cannot fire during a
  `BGAppRefreshTask`. Moving the dispatch into the task handler is a v1
  blocker.
- **Re-decision trigger.** If user feedback shows that polling cadence is
  inadequate, or if a party-operated push relay becomes available, revisit.
