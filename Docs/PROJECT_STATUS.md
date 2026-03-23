# Project Status

Last updated: 2026-03-18

---

## Current State

No active milestone. The app is in an **enhancement and stabilisation phase** following the completion of all planned milestones (M1–M8). Recent work consists of UI improvements, bug fixes, and new cross-cutting features.

---

## Recent Enhancements

### Notifications: Replaced APNs Push with Client-Side Polling (2026-03-23)

- Replaced APNs push notification infrastructure with client-side polling of Discourse `/notifications/totals.json` (see D-036)
- Removed `DeviceTokenManager`, `PushNotificationRegistrationService`, `BackendPushNotificationRegistrationService`, `FakePushNotificationRegistrationService`
- Added `DiscourseNotificationPoller` — polls Discourse every 60s in foreground, creates local notifications on count increase
- Simplified 4 per-category notification toggles to single "Benachrichtigungen" toggle
- Removed `aps-environment` entitlement (no longer using APNs)
- Eliminates dependency on Rails server for notification delivery

### News Notifications + Background Polling (2026-03-18)
**Branch:** `feature/news-notifications-and-polling`

- `ForumViewModel` and `NewsViewModel` now start a 3-minute repeating timer on init that silently fetches new content and updates the badge dot without disrupting the visible list
- Badge dot color changed from system red to `piratenPrimary` (`#FF8800`) in `PiratenIconButton`; tab bar badge was already using piratenPrimary

### Fix: Expanded Post Content Truncated (2026-03-18)
**PR:** #52 — merged

- `SelectableTextView` (UITextView wrapper) did not implement `sizeThatFits(_:uiView:context:)`, so SwiftUI could not calculate the correct height for long expanded forum posts
- Fixed by adding `sizeThatFits` and `invalidateIntrinsicContentSize()` on content updates
- Replaced deprecated `UIScreen.main` with `uiView.superview?.bounds.width ?? 300`

### Feedback Section in Kajüte (2026-03-17)
**PR:** #51 — merged

- Added thumbs-up / thumbs-down feedback buttons to the Kajüte dashboard
- `FeedbackViewModel` handles submission; `FeedbackComposeView` collects optional freetext
- Wired through `AppContainer.makeFeedbackViewModel(type:)` factory

### Private Messages Redesigned as Chat Bubbles (2026-03-08)
**PR:** #50 — merged

- Replaced flat symmetric message list with directional chat bubbles
- Sent messages: right-aligned, piratenPrimary tint; received: left-aligned, surface background
- Text selection enabled via `SelectableTextView`; removed redundant calendar header
- See DECISIONS.md D-035

---

## Completed Milestones

### Milestone 8: Knowledge Hub (Wissen) — Complete ✅
**Completed:** 2026-02-19

Goal: Fetch educational content from the public GitHub repo `sebulino/PIRATEN-Kanon`, cache it locally, and present interactive lessons with progress tracking, quizzes, and checklists.

**Delivered:**
- `GitHubAPIClient` with ETag conditional requests
- Custom YAML frontmatter parser + markdown content section parser
- File-based cache (`<Caches>/Knowledge/`) with 24h TTL and atomic writes
- `ReadingProgressStore` (UserDefaults-backed, protocol-injected)
- `KnowledgeViewModel` + `KnowledgeTopicDetailViewModel`
- Full UI: `KnowledgeView`, `CategoryDetailView`, `KnowledgeTopicDetailView` with quiz, checklist, callout, and overview cards
- Tests: FrontmatterParserTests, ContentSectionParserTests, ReadingProgressStoreTests

### Kajüte (Home) + Termine (Calendar) Tabs — Complete ✅
**Completed:** 2026-02-19

**Kajüte (Tab 0):** Dashboard aggregating recent message contacts, in-progress knowledge articles, and latest forum topics. Each section loads independently.

**Termine (Tab 4):** iCal feed from piragitator.de, custom RFC 5545 parser, upcoming and past event sections, public endpoint (no auth).

**Tab layout finalised:** 5 tabs (Kajüte=0, Forum=1, Wissen=3, Termine=4, ToDos=5). Messages and News are modal sheets accessible from the toolbar on every tab. See DECISIONS.md D-029.

### Milestone 7: Real Todo API Integration — Complete ✅
REST client for the meine-piraten.de Rails server. DTOs, `TodoAPIClient`, `RealTodoRepository`. Domain model aligned to server schema (entities, categories, comments).

### Milestone 6: Actionable Todos (Write Operations) — Complete ✅
Create, claim, complete, unclaim, comment, and delete (hidden from UI) for Todos. Full UI with `TodoDetailView`, `CreateTodoView`, `TodoRow`. `FakeTodoRepository` with in-memory data.

### Milestone 5: Notifications — Complete ✅
Client-side polling of Discourse notification counts with local notification delivery. Single opt-in toggle in ProfileView. Deep link routing from notification taps. Originally APNs-based, replaced with polling (see D-036).

### Milestone 4: Private Messages — Complete ✅
Message thread list, compose flow, recipient picker, recent recipients, draft storage. Forum post replies and PM replies share `ReplyComposerView`.

### Milestone 3: Forum Integration — Complete ✅
Discourse API client, topic listing, post viewing with expand/collapse, like, reply. User API Key authentication for Discourse (RSA + ASWebAuthenticationSession).

### Milestone 2: Authentication — Complete ✅
SSO integration via AppAuth-iOS (OIDC/OAuth2 + PKCE). Token storage in Keychain. Session management with `AuthStateManager`.

### Milestone 1: Bootstrap — Complete ✅
Clean Architecture folder structure, auth state machine, tab bar shell, xcconfig configuration system, Keychain service, documentation scaffold.

---

## Known Limitations

| Area | Limitation | Tracked |
|------|-----------|---------|
| Notifications | Client-side polling of Discourse `/notifications/totals.json` every 60s; local notifications on count increase (D-036) | — |
| Forum | First page only (no pagination) | Q-012 |
| Calendar | No RRULE recurrence support — recurring events show first occurrence only | Q-020 |
| Knowledge | Progress stored locally only — lost on reinstall, not synced across devices | Q-016 |
| Background polling | Timer only runs while app is foregrounded — backgrounded users see no badge updates | — |

---

## Blockers

See [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) for items requiring external input before implementation can proceed.
