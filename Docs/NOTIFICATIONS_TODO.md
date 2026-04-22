# Notifications — TODO

**Branch:** `feature/api-call-optimization`
**Captured:** 2026-04-20
**Last updated:** 2026-04-22 — T-1 and T-2 landed (see D-037). G-1, G-2 closed.
**Status of this doc:** gap analysis, not a spec. Intended behavior is the
project owner's description; actual behavior is what the code on this branch
does today.

---

## 1. Intended behavior

- **Background (app closed or suspended):**
  - For every section the user has enabled in settings (currently Messages,
    Forum, Todos, News), the app polls roughly every 30 minutes.
  - When new content is detected for an enabled section, the app-icon badge
    updates and/or a local notification is raised for that section.
  - Per-category settings gate **what gets polled** and **what gets notified**.

- **Foreground (app open):**
  - Tab dots reflect new content without the user having to visit the tab.
  - Messages dot updates roughly every 60 seconds.
  - (Cadence for Forum/Todos/News in foreground: to be confirmed — see
    open questions below.)

---

## 2. Actual behavior on this branch

### 2.1 Background path

- Single mechanism: `BGAppRefreshTask` registered in
  `PIRATEN/App/AppDelegate.swift:31-32`, handler in
  `PIRATEN/Core/Data/Notifications/BackgroundTaskScheduler.swift`.
- Handler calls `notificationPoller.poll()` exactly once per wake-up.
- `DiscourseNotificationPoller.poll()` issues one request:
  `GET /notifications/totals.json` on Discourse.
  (`PIRATEN/Core/Data/Notifications/DiscourseNotificationPoller.swift:60-86`,
  `101-109`.)
- `poll()` updates `lastKnownTotal` in UserDefaults and sets the app-icon
  badge to the total — nothing else.

### 2.2 Foreground path

- `MainTabView.startPollingIfNeeded()`
  (`PIRATEN/App/Views/Main/MainTabView.swift:538-549`): 60 s `Timer` while the
  tab view is on screen and `anyNotificationsEnabled` is true.
- Each tick calls `notificationPoller.poll()` plus
  `refreshDeliveredNotificationsCount()`. It does **not** call any
  ViewModel's `loadXxx()`.
- Also fires once on scene `.active` transition
  (`MainTabView.swift:422-427`).

### 2.3 Local notification scheduling

- Lives in `.onChange` observers in `MainTabView.swift:442-477`, one per
  section. They watch `messagesViewModel.hasNewContent`, `forumViewModel
  .hasNewContent`, `todosViewModel.hasNewContent`, `newsViewModel
  .hasNewContent` and call `scheduleLocalNotification(...)` when a flag
  flips from false to true **and** the matching category setting is on.
- `hasNewContent` is only set inside each ViewModel's `loadXxx()` method
  (e.g. `ForumViewModel.updateNewContentFlag()`,
  `MessagesViewModel` tracking `lastKnownMessageCount`, etc.).

---

## 3. Gaps vs. intent

### G-1: Background polling is not per-section ✅ CLOSED (D-037, 2026-04-22)
- ~~Only Discourse's aggregate `unread_notifications` is fetched.~~
- ~~Cannot distinguish Messages vs Forum in the background.~~
- ~~**Todos, News never checked in background.**~~
- Now: `BackgroundRefreshCoordinator.run()` polls all six sources (Forum,
  Messages, Todos, News, Knowledge, Events) in parallel via TaskGroup. Each
  source has its own `bg_*_last_seen_*` UserDefaults marker.

### G-2: Background polling never raises a local notification ✅ CLOSED (D-037, 2026-04-22)
- ~~`poll()` only calls `setBadgeCount`.~~
- ~~Only code path was SwiftUI `.onChange` observers in `MainTabView`.~~
- Now: dispatch logic extracted into `LocalNotificationScheduler` (plain
  object). Both the headless `BackgroundRefreshCoordinator` and the
  foreground `.onChange` observers call the shared scheduler. Titles/bodies
  consolidated on the `NotificationCategory` enum. OPEN-12 fixed.

### G-3: Per-category settings gate display, not polling
- `notificationSettings.messagesEnabled` etc. are checked inside the
  `.onChange` handlers.
- The background and foreground pollers hit `totals.json` regardless
  of which categories are on. Turning Forum off while keeping Messages
  on does not change what gets fetched.

### G-4: Foreground 60 s timer does not update per-tab dots
- Messages tab dot is driven by `messagesViewModel.hasNewContent`,
  which is set inside `loadMessages()`.
- The foreground timer calls `notificationPoller.poll()`, not
  `loadMessages()`. So the Messages dot only updates when the user
  actually opens the tab, and even then the `StalenessGuard`
  (`PIRATEN/Core/Support/StalenessGuard.swift`, 120 s for Messages)
  may short-circuit the call.
- Same blind spot for Forum, Todos, News tab dots — nothing in the
  foreground polls them.

### G-5: "Every 30 minutes" is aspirational
- `BGAppRefreshTaskRequest.earliestBeginDate = now + 30 min`
  (`BackgroundTaskScheduler.swift:18`). iOS decides the actual cadence;
  it is often much less frequent, varies with usage patterns, charging,
  screen time budget, etc.
- No foreground-fallback path when background refresh is throttled.

### G-6: iOS app-icon badge is a single number
- `setBadgeCount(newTotal)` uses Discourse's aggregate count only.
- No composition with Todos/News unread counts. No per-section visual
  distinction on the home screen is possible without changing how the
  badge is computed.

### G-7: On cold start, per-tab dots are wrong until tab is opened
- `StalenessGuard` state is in-memory only and resets on launch.
- However, the aggregate Discourse badge is initialized from
  UserDefaults (`lastKnownTotal`), so the app-icon badge on first
  render reflects the last known value — fine.
- The in-app tab dots however wait for the first `loadXxx()` call on
  each tab. Staggered launch in `MainTabView.onAppear` triggers those
  loads, so in practice dots appear within a few seconds of launch,
  but the timing is staggered and uneven (Messages immediate, Todos
  at +1 s, Forum at +3 s, Calendar and Knowledge only on first tab
  open).

---

## 4. Things to decide before implementing

These block a clean fix. They belong in `OPEN_QUESTIONS.md` but are
collected here for context.

- **Q-N1:** Per-category background cadence. Same 30 min for all four
  sections, or different intervals per section (news less often,
  messages more often)?
- **Q-N2:** How to poll Todos and News in the background. They have no
  `totals.json`-style endpoint. Does the app need to pull the full
  list and compare ids, or does meine-piraten.de offer a cheaper
  counter?
- **Q-N3:** When multiple sections have new content in a single
  background wake-up, one combined notification or one per section?
- **Q-N4:** App-icon badge semantics. Just Discourse unread? Sum across
  all four sections? Or "1 if anything is new, else 0" (already present
  as `anyContentUnread` path in `MainTabView.swift:478-484`, competes
  with the `notificationPoller` badge updates)?
- **Q-N5:** Foreground cadence for Forum / Todos / News tab dots.
  User mentioned 60 s for Messages only — should the others also
  refresh at 60 s, at their `StalenessGuard` interval, or only on tab
  focus?
- **Q-N6:** Rate-limit budget on Discourse. The earlier 429 incident is
  why the ViewModel timers were removed. Any new foreground-refresh
  path has to fit inside that budget.

---

## 5. Proposed work items

Each item is independently reviewable. Order is suggested, not required.

### T-1: Make background polling per-section and notification-capable ✅ DONE (D-037, 2026-04-22)
- Introduced `BackgroundRefreshCoordinator` invoked by
  `BackgroundTaskScheduler.handleAppRefresh`.
- Polls all six sources (Forum, Messages, Todos, News, Knowledge, Events)
  in parallel via `TaskGroup`. Each child has its own `do/catch` so one
  source's failure does not block the siblings.
- Uses its own `bg_*` prefixed UserDefaults keys (deliberately separate
  from the ViewModels' existing keys — see D-037 rationale §5).
- Each poll respects its category toggle: the fetch runs regardless
  (so that flipping a toggle on later does not flood with stale items)
  but the dispatch is gated on `settings.<category>Enabled`.
- Composite app-icon badge: NOT changed. `DiscourseNotificationPoller`
  still owns the aggregate-unread badge; coordinator runs before it
  in the same BG wake-up. Folding the two is deferred (see D-037
  Consequences / Future Decisions).

### T-2: Schedule notifications from the coordinator, not from the view ✅ DONE (D-037, 2026-04-22)
- `scheduleLocalNotification(...)` removed from `MainTabView`. Logic now
  lives in `LocalNotificationScheduler` (plain struct, protocol-based so
  tests can fake it).
- Titles/bodies moved to the `NotificationCategory` enum — one definition
  covers both paths.
- Kept the `.onChange` observers for foreground zero-latency banners (now
  calling `dispatchLocalNotification(_ category:)` which delegates to the
  same scheduler). Added two new observers for Knowledge and Events to
  reach parity with the six-category background coordinator.

### T-3: Fix foreground tab-dot refresh
- Decide per Q-N5. Simplest option: add a single foreground "refresh
  dots" cycle that, while the app is active, triggers lightweight
  per-section loads on a 60 s cadence for Messages and a slower
  cadence (e.g. 5 min) for Forum/Todos/News, bypassing the
  `StalenessGuard` for these polls.
- Alternative: have each ViewModel expose a cheap "badge-only" check
  that doesn't refresh the full content list — avoids pulling full
  topic/thread bodies just to see if there's one more id.

### T-4: Test matrix
- Unit: `BackgroundRefreshCoordinator` correctly honors per-category
  settings, doesn't poll disabled sections, persists last-seen ids,
  and schedules the right titles/bodies.
- Integration: simulate `BGAppRefreshTask` fire with fake repositories
  returning "one new item per section" and assert the exact set of
  `UNNotificationRequest`s scheduled.
- Manual: verify on device that notifications appear when app is truly
  backgrounded (simulator's `simctl push` path is not sufficient —
  the real `BGAppRefreshTask` timing is what we care about).

### T-5: Documentation follow-ups
- Update `Docs/DECISIONS.md` with the reasoning for per-section
  background polling (and the cost/battery trade-off).
- Update `Docs/API_REQUEST_MAP.md` to list the new background calls.
- Update `Docs/PROJECT_STATUS.md` once any of T-1…T-3 lands.
- Close the relevant questions in `Docs/OPEN_QUESTIONS.md` as they are
  answered.

---

## 6. Non-goals / explicit out of scope

- Introducing APNs push. The project has deliberately chosen client-side
  polling (see commit `a163287` "Replace APNs push notifications with
  client-side Discourse polling" and
  `Docs/PUSH_NOTIFICATIONS_RAILS_PRD.md`).
- Server-side aggregation or a notification relay endpoint. Everything
  stays on-device for privacy.
- Reviving the per-ViewModel `Timer.scheduledTimer` polling that the
  StalenessGuard refactor removed. That path hit the Discourse
  rate-limit and will not come back.
