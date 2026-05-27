# Decisions Log — MeinePIRATEN

Running list of questions surfaced by the gap analysis between the requirements
/ architecture documents and the actual codebase. Each entry is answered once
and then used to update the requirements, architecture, or ADRs.

**Format**

- **ID** — stable, do not renumber.
- **Category** — rough grouping for navigation.
- **Context** — one line, why this question exists.
- **Code state** — what the codebase does today.
- **Docs state** — what the documents say today.
- **Decision** — filled by Sebastian.
- **Follow-up** — what Claude will change in the docs once the decision is made.

Status key: `OPEN` · `DECIDED` · `APPLIED` (i.e. the docs have been updated).

---

## Platform & scope

### Q-001 — Minimum iOS version
- **Status:** DECIDED
- **Context:** Code and docs disagree on the deployment target.
- **Code state:** `IPHONEOS_DEPLOYMENT_TARGET = 26.2`.
- **Docs state:** NFR-001 says iOS 16.0.
- **Decision:** iOS 26.2 is the minimum deployment target for v1.
- **Follow-up:** Update NFR-001 in `requirements.md` and ADR-0001 in `adr/0001-native-swiftui-app.md` to say iOS 26.2.

### Q-002 — iPad support
- **Status:** DECIDED
- **Context:** Project has two conflicting `TARGETED_DEVICE_FAMILY` values ("1,2" and "1").
- **Code state:** Ambiguous.
- **Docs state:** Implicitly iPhone-only.
- **Decision:** iPhone only. v1 does not support iPad.
- **Follow-up:** Clean up the Xcode project setting to a single consistent `TARGETED_DEVICE_FAMILY = 1`. Add a sentence to NFR-001 in `requirements.md` stating iPhone-only.

### Q-003 — Localisation strategy
- **Status:** DECIDED
- **Context:** The app is German-only today, with no localisation scaffolding.
- **Code state:** Zero `Localizable.strings`, zero `String(localized:)`. All strings are hardcoded German literals.
- **Docs state:** NFR-002 / ADR-0008 imply `Localizable.strings` with `de` as base.
- **Decision:** German-only for v1. Internationalisation is a planned future goal, but not in scope for v1. No `Localizable.strings` required now.
- **Follow-up:** Update NFR-002 and ADR-0008 to reflect: v1 ships German-only with hardcoded strings; i18n readiness is explicitly deferred to a post-v1 milestone.

### Q-004 — Licence
- **Status:** DECIDED
- **Context:** No `LICENSE` file in repo. NFR-012 requires a free-software licence.
- **Code state:** Absent.
- **Docs state:** OPEN-05.
- **Decision:** EUPL-1.2
- **Follow-up:** Close OPEN-05 in `open-issues.md`. Update NFR-012 in `requirements.md` to name EUPL-1.2 explicitly. A `LICENSE` file needs to be added to the repo (not a docs task, but flagged).

---

## Architecture foundations

### Q-005 — Cache technology
- **Status:** DECIDED
- **Context:** Documented cache technology does not match what is shipped.
- **Code state:** `UserDefaults` (JSON-encoded) + filesystem JSON + scalar `UserDefaults`. Three idioms, no central `Cache` protocol.
- **Docs state:** ADR-0005 says SQLite via GRDB.
- **Decision:** Accept reality. UserDefaults-JSON and filesystem-JSON are the v1 cache. ADR-0005 (GRDB) is to be replaced by a new ADR-0010 reflecting the actual approach.
- **Follow-up:** Write ADR-0010 replacing ADR-0005. Mark ADR-0005 as "Superseded by ADR-0010". Update `architecture.md` cache section accordingly.

### Q-006 — Central logger
- **Status:** DECIDED
- **Context:** No unified logger facade.
- **Code state:** Exactly one `os.Logger` instance, seven ungated `print()` sites.
- **Docs state:** `architecture.md §2` lists a Logger layer in `Core`.
- **Decision:** Introduce a minimal logger facade wrapping `os.Logger`. Replace all `print()` call sites. `LogRedactor` becomes mandatory for any value that could contain PII or tokens.
- **Follow-up:** Update `architecture.md` to describe the Logger layer concretely. Add as a code task (not a docs task).

### Q-007 — `AppContainer.shared` singleton escape hatch
- **Status:** DECIDED
- **Context:** DI is otherwise constructor-based; one singleton exists for `BackgroundTaskScheduler`.
- **Code state:** `AppContainer.shared` exists solely so `BackgroundTaskScheduler` can reach the notification poller from a non-UI context.
- **Docs state:** Not mentioned anywhere.
- **Decision:** Accept and document. The singleton is a deliberate, narrowly scoped exception to the DI model, required by iOS background task architecture (BGAppRefreshTask callbacks have no dependency injection point).
- **Follow-up:** Add a section to `architecture.md` describing the notification background task architecture, including the role of `AppContainer.shared` and why it is limited to this one use case. This also partially addresses Q-038 (notifications v1 scope).

### Q-008 — No app-specific backend in v1 (ADR-0004)
- **Status:** DECIDED
- **Context:** Revisit whether the decision still holds given implementation progress.
- **Code state:** No backend.
- **Docs state:** ADR-0004 accepted.
- **Decision:** Confirmed. ADR-0004 stands unchanged.
- **Follow-up:** None. ADR-0004 remains Accepted.

### Q-009 — Repository pattern with fake implementations
- **Status:** DECIDED
- **Context:** Code rigorously uses `Real*Repository` / `Fake*Repository` per feature as a test seam.
- **Code state:** `Fake*Repository` implementations exist and are wired into `AppContainer` for dev use.
- **Docs state:** Not recorded as a decision.
- **Decision:** `Fake*Repository` implementations are for unit tests only and must not be wired into any non-test target. In dev and production, `Real*Repository` is always used. While data is loading or the cache is empty, the UI shows skeleton / placeholder states — never fake data. This is a code correction as well as a documentation decision.
- **Follow-up:** Add this as a rule to `architecture.md`. Flag to Claude Code that `AppContainer` wiring of `Fake*` repositories outside of test targets is a bug to fix.

### Q-010 — Hand-rolled parsers vs. libraries
- **Status:** DECIDED
- **Context:** iCal, frontmatter, HTML, and RSA handling are all hand-rolled. Only AppAuth is a third-party dep.
- **Code state:** Minimal-deps in practice.
- **Docs state:** Not recorded.
- **Decision:** Deliberate. Minimal dependencies is a first-class principle: lightweight implementations are preferred over pulling in full libraries. New dependencies require explicit justification.
- **Follow-up:** Write ADR-0013 "Minimal third-party dependencies". Update `architecture.md` to mention this principle.

---

## Authentication & identity

### Q-011 — Name the identity provider concretely
- **Status:** DECIDED
- **Context:** Docs use the abstract "PiratenSSO"; code targets a specific Keycloak realm.
- **Code state:** Keycloak realm `Piratenlogin` via AppAuth-iOS.
- **Docs state:** ADR-0003 uses the abstract term.
- **Decision:** Keep the abstraction. ADR-0003 refers to "PiratenSSO" only. The concrete Keycloak implementation detail lives in `integrations.md` and `Secrets.xcconfig`, not in the ADR.
- **Follow-up:** No change to ADR-0003. Update `integrations.md §1` to mention Keycloak as the current implementation behind PiratenSSO, without making it normative.

### Q-012 — Keycloak realm per build flavour
- **Status:** DECIDED
- **Context:** Whether dev/staging/prod builds should point at different realms.
- **Code state:** Single pinned realm for all builds.
- **Docs state:** Silent.
- **Decision:** Single PiratenSSO realm for dev, staging and production. Unit and UI tests use stubs and never hit the live SSO. A dedicated staging realm is not planned for v1 — contributors are party members and authenticate with their real accounts during development.
- **Follow-up:** Document in `integrations.md §1`. Note the test-stub approach as a requirement for any CI pipeline (Q-050).

### Q-013 — Discourse auth path (OPEN-07)
- **Status:** DECIDED
- **Context:** Docs left this as two options; code has picked one.
- **Code state:** User API Key via `/user-api-key/new` (RSA-encrypted handshake). Verified working against live Discourse instance.
- **Docs state:** OPEN-07 still open.
- **Decision:** Confirmed. Discourse authentication uses the User API Key flow. Close OPEN-07.
- **Follow-up:** Write ADR-0009 "Discourse authentication via User API Key". Close OPEN-07 in `open-issues.md`.
- **Follow-up:** _pending_

### Q-014 — Discourse host per build flavour
- **Status:** DECIDED
- **Context:** Same question as Q-012, for Discourse.
- **Code state:** Single host via `.xcconfig`.
- **Docs state:** Silent.
- **Decision:** Single Discourse host (`diskussion.piratenpartei.de`) for dev, staging and production. Tests use stubs and never hit the live instance.
- **Follow-up:** Document in `integrations.md §2`.

### Q-015 — `handleAuthenticationError()` is disabled
- **Status:** DECIDED
- **Context:** `AuthStateManager.swift:128` prints a warning and does nothing.
- **Code state:** Intentionally inert, reason unknown.
- **Docs state:** Not mentioned.
- **Decision:** Track as open issue. Needs investigation before v1 ship: what triggers it, why it was disabled, and what the correct behaviour is (force logout / error screen / silent retry).
- **Follow-up:** Add as OPEN-09 in `open-issues.md`.

### Q-016 — Biometric re-auth (FR-AUTH-006, "Could")
- **Status:** DECIDED
- **Context:** Should Face ID / Touch ID gating be in v1?
- **Code state:** Not implemented.
- **Docs state:** Could.
- **Decision:** Stays "Could", deferred to a later version.
- **Follow-up:** No change to requirements.
- **Follow-up:** _pending_

---

## Data & persistence

### Q-017 — Schema migrations
- **Status:** DECIDED
- **Context:** JSON stores decode best-effort; no versioning.
- **Code state:** No migrations.
- **Docs state:** Silent.
- **Decision:** Implement a simple version-bump migration strategy for all JSON stores. Each store persists a version integer alongside its data. On launch, if the stored version is outdated, the cache is cleared and data is re-fetched from the network. No data transformation required since all cached data is re-fetchable.
- **Follow-up:** Add as a requirement in `requirements.md` (NFR). Flag to Claude Code as a code task across all stores.

### Q-018 — Keychain accessibility class
- **Status:** DECIDED
- **Context:** Codify what the code already does.
- **Code state:** `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- **Docs state:** Silent.
- **Decision:** Confirmed. `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` is correct. Tokens do not survive device migration or iCloud restore; users re-authenticate on a new device.
- **Follow-up:** Document in `architecture.md` Keychain section and NFR-006 in `requirements.md`.

### Q-019 — Forum category pins
- **Status:** DECIDED
- **Context:** Where to store category pins and whether the feature ships in v1.
- **Code state:** Not implemented.
- **Docs state:** FR-FORUM-005 (Should).
- **Decision:** Ships in v1. Promote FR-FORUM-005 from Should to Must. Pin state is stored in UserDefaults, device-local only.
- **Follow-up:** Update FR-FORUM-005 in `requirements.md` to Must. Add storage detail (UserDefaults, device-local).

---

## Forum & messaging

### Q-020 — Forum v1 scope
- **Status:** DECIDED
- **Context:** Code implements list/read/reply/like/read-state. Category filter decided in Q-019.
- **Code state:** List, read, reply, like, read-state implemented. No new topic creation.
- **Docs state:** FR-FORUM-* covers list/read/reply/like/read-state/category filter.
- **Decision:** v1 scope is: list, read, reply, like/unlike (synced to Discourse — see OPEN-02), read-state, category pins (Q-019), and new topic creation (Should). Likes/unlikes remain a known hard problem; OPEN-02 stays open and must be resolved before v1 ship.
- **Follow-up:** Add FR-FORUM-008 (Should) "User can create a new forum topic" to `requirements.md`. Sharpen OPEN-02 to reflect failed attempts and the need for a concrete solution path.

### Q-021 — Inline images in forum posts (FR-FORUM-006, "Could")
- **Status:** DECIDED
- **Context:** Posts containing images currently render without them.
- **Code state:** Not implemented.
- **Docs state:** FR-FORUM-006 (Could).
- **Decision:** Promote to Must for v1. Inline images must render in forum posts. Image sizing must be respected — images are displayed at their natural aspect ratio and never stretched beyond their actual dimensions.
- **Follow-up:** Update FR-FORUM-006 in `requirements.md` to Must, add explicit note about aspect ratio / no stretching.

### Q-022 — Likes against Discourse (OPEN-02)
- **Status:** DECIDED — implementation 2026-04-22 via [ADR-0014](./adr/0014-like-strategy-chain.md).
- **Context:** Code implements `POST /post_actions.json`. Does it actually work in production?
- **Code state:** Like is displayed optimistically on device only. It is never pushed through to the Discourse instance.
- **Docs state:** OPEN-02 flagged as potentially blocked by CSRF / API key scope.
- **Decision:** Likes must work end-to-end in v1 — optimistic-only is not acceptable. Two prior investigation paths have failed: analysis of the official Discourse mobile app yielded no insights, and following the API docs did not produce results. A fresh, focused investigation of the `POST /post_actions.json` endpoint is required, including checking request headers, CSRF token handling, and User API Key scope. OPEN-02 stays open until a working solution is found.
- **Resolution.** Rather than picking one hypothesis, we ship a strategy chain (`LikeStrategyRegistry`) that probes the discourse-reactions plugin endpoint, then a form-encoded `/post_actions.json`, then the original JSON variant. The first to return a confirmed 2xx wins and is cached per install. See ADR-0014 for the rationale and trade-offs.
- **Follow-up:** Once TestFlight observation identifies which strategy actually wins on the live instance, narrow `LikeStrategyRegistry.all` to that single strategy.

### Q-023 — Messages tab-switch loads inbox only
- **Status:** DECIDED
- **Context:** Tab switch fetches inbox; pull-to-refresh fetches both halves. Intentional?
- **Code state:** Tab switch fetches inbox only.
- **Docs state:** Not specified.
- **Decision:** Intentional. Inbox is fetched automatically on tab switch. Sent messages are fetched only on explicit pull-to-refresh, since they change rarely and do not need to trigger an API call on every tab visit.
- **Follow-up:** Document this behaviour in `requirements.md` under FR-MSG.

### Q-024 — Starting new DMs (FR-MSG-004, "Should")
- **Status:** DECIDED
- **Context:** Code has `ComposeMessageView` + `RecipientPicker`. Promote to Must for v1?
- **Code state:** Implemented.
- **Docs state:** FR-MSG-004 (Should).
- **Decision:** Promote to Must. Feature is implemented and working.
- **Follow-up:** Update FR-MSG-004 in `requirements.md` to Must.

---

## Knowledge (Kanon)

### Q-025 — Kanon pinning (ADR-0007)
- **Status:** DECIDED
- **Context:** ADR describes per-release commit pinning with bundled fallback; code fetches live from `main`.
- **Code state:** Live fetch, no SHA tracking, no bundle fallback.
- **Docs state:** ADR-0007 accepted — but describes the wrong model.
- **Decision:** The app stores the commit SHA of the last successfully downloaded Kanon content. On startup it fetches the latest remote SHA from GitHub. If the remote SHA differs, it downloads and caches the updated content. If GitHub is unreachable, locally cached content is used. No per-app-release pinning, no bundled content.
- **Follow-up:** Replace ADR-0007 with ADR-0011 describing this SHA-tracking model. Mark ADR-0007 as "Superseded by ADR-0011". Flag SHA tracking as a code task.

### Q-026 — Kanon repo ownership
- **Status:** DECIDED
- **Context:** `sebulino/PIRATEN-Kanon` is a personal repo.
- **Code state:** Hardcoded as `sebulino/PIRATEN-Kanon` in `Secrets.xcconfig`.
- **Docs state:** References `sebulino/PIRATEN-Kanon` throughout.
- **Decision:** The repo will be moved to the `piratenpartei` GitHub organisation. Until the move happens, `sebulino/PIRATEN-Kanon` remains. The repo owner/name must be configurable via `Secrets.xcconfig` (already the case) so the move requires no code change.
- **Follow-up:** Add as OPEN-10 in `open-issues.md`: transfer `sebulino/PIRATEN-Kanon` to `piratenpartei` org. Update all doc references to note the intended final location.

### Q-027 — GitHub rate-limiting
- **Status:** DECIDED
- **Context:** Anonymous GitHub API = 60 req/h/IP. Risk for app rollout?
- **Code state:** Anonymous requests.
- **Docs state:** Silent.
- **Decision:** Accept for v1. Revisit if rate limiting becomes a user-visible problem in practice.
- **Follow-up:** No change needed now. Note in `integrations.md §5` as a known constraint.

### Q-028 — Quiz progress storage (OPEN-08)
- **Status:** DECIDED
- **Context:** Code stores in `ReadingProgressStore` (UserDefaults) keyed per-topic.
- **Code state:** Implemented, device-local only.
- **Docs state:** OPEN-08.
- **Decision:** Sufficient for v1. Close OPEN-08.
- **Follow-up:** Close OPEN-08 in `open-issues.md`.

### Q-029 — Kanon authoring schema
- **Status:** DECIDED
- **Context:** Frontmatter + section-block format needed by external authors. Is the parser the only spec?
- **Code state:** `FrontmatterParser.swift` and `ContentSectionParser.swift` are the de facto spec.
- **Docs state:** Not documented anywhere.
- **Decision:** A schema document must exist in the Kanon repo so external authors can contribute without reading Swift code. It should cover: required and optional frontmatter fields, all supported section block types with examples, quiz question format, and level/category values.
- **Follow-up:** Add as OPEN-11 in `open-issues.md`: write `AUTHORING.md` in the Kanon repo. This is a content task, not a code task.

---

## Events

### Q-030 — "Agitatorrr" vs. "Piragitator" name + endpoint
- **Status:** DECIDED
- **Context:** Docs say Agitatorrr/JSON, code talks to Piragitator/iCal.
- **Code state:** `piragitator.de`, iCal feed.
- **Docs state:** `agitatorrr.de`, JSON assumed.
- **Decision:** Same service, two domains. Use `agitatorrr.de` as the canonical domain. Parse the iCal feed (not JSON). Update `PIRAGITATOR_BASE_URL` in `Secrets.xcconfig` to `agitatorrr.de`.
- **Follow-up:** Update `integrations.md §3` to use `agitatorrr.de` and describe the iCal feed. Update all doc references from "Piragitator" to "Agitatorrr". Update the glossary.

### Q-031 — EventKit integration (FR-EVT-003, "Should")
- **Status:** DECIDED
- **Context:** "Add to calendar" with one tap via EventKit.
- **Code state:** Not implemented.
- **Docs state:** FR-EVT-003 (Should).
- **Decision:** Promote to Must for v1.
- **Follow-up:** Update FR-EVT-003 in `requirements.md` to Must.

### Q-032 — Region filter (FR-EVT-004, "Could")
- **Status:** DECIDED
- **Context:** Filtering events by Landesverband / region.
- **Code state:** Not implemented.
- **Docs state:** FR-EVT-004 (Could).
- **Decision:** Deferred to post-v1. Stays as "Could".
- **Follow-up:** No change to requirements.

---

## ToDos

### Q-033 — ToDo API contract (OPEN-03)
- **Status:** DECIDED
- **Context:** Is there a backend-side contract doc, or is `TodoAPIClient.swift` the spec?
- **Code state:** `TodoAPIClient.swift` implements against live endpoints.
- **Docs state:** OPEN-03 open.
- **Decision:** Full API documentation exists at `https://meine-piraten.de/api`. Close OPEN-03.
- **Follow-up:** Close OPEN-03. Update `integrations.md §4` with the full endpoint table from the API docs. Note the task status state machine (open → claimed → completed → done) in `requirements.md` FR-TODO.

### Q-034 — Releasing a taken ToDo (FR-TODO-005, "Could")
- **Status:** DECIDED
- **Context:** Can a user release a task they have claimed back to the pool?
- **Code state:** Not implemented.
- **Docs state:** FR-TODO-005 (Could).
- **Decision:** Promote to Must for v1. The API supports the `claimed` → `open` status transition for any authenticated user.
- **Follow-up:** Update FR-TODO-005 in `requirements.md` to Must.

### Q-035 — Background refresh for ToDos
- **Status:** DECIDED
- **Context:** Notification/badge for new ToDos?
- **Code state:** Refresh on tab open only.
- **Docs state:** Silent.
- **Decision:** Background polling every 30 minutes via BGAppRefreshTask, plus refresh on tab open. New or updated tasks update the tab badge count.
- **Follow-up:** Add FR-TODO-006 to `requirements.md`. Flag to Claude Code as a code task: extend `BackgroundTaskScheduler` to include ToDo polling alongside the existing Discourse notification poll.

---

## News

### Q-036 — News API authentication
- **Status:** DECIDED
- **Context:** Currently public. Stay public?
- **Code state:** No auth on news requests.
- **Docs state:** `integrations.md` says "public in v1".
- **Decision:** Confirmed. News endpoint stays public. No change needed.
- **Follow-up:** None.

### Q-037 — News mark-as-read (FR-NEWS-004, "Could")
- **Status:** DECIDED
- **Context:** Code has a `lastSeenNewsKey`; spec might mean per-item read state.
- **Code state:** "Last seen" tracking via `lastSeenNewsKey`. Tab badge clears when user visits the tab.
- **Docs state:** FR-NEWS-004 (Could).
- **Decision:** "Last seen" approach is sufficient for v1. Per-item read state is deferred. FR-NEWS-004 stays as "Could".
- **Follow-up:** Update FR-NEWS-004 in `requirements.md` to clarify that v1 uses a "last seen" model, not per-item read state.

---

## Notifications

### Q-038 — Notifications v1 scope
- **Status:** DECIDED
- **Context:** Aggregate badge works, foreground `.onChange` local notifications work, BG-task dispatch does not.
- **Code state:** Local notification dispatch only wired to SwiftUI `.onChange` observers — fires only while app is running.
- **Docs state:** ADR-0006 describes polling only; local notifications not mentioned.
- **Decision:** The BGAppRefreshTask must also dispatch local iOS notifications (banner + sound) when it finds new activity. Notification dispatch logic must move out of SwiftUI `.onChange` observers and into the background task handler.
- **Follow-up:** Add as OPEN-12 in `open-issues.md` (bug: BG task does not dispatch local notifications). Update ADR-0006 to include local notification dispatch as part of the v1 notification model. Update FR-NOTIF in `requirements.md`.

### Q-039 — BG-dispatch bug
- **Status:** DECIDED
- **Context:** Fix in v1 or accept as v1 limitation?
- **Decision:** Fix in v1. Answered by Q-038. Tracked as OPEN-12.
- **Follow-up:** See Q-038.

### Q-040 — APNs push (OPEN-01)
- **Status:** DECIDED
- **Context:** ADR-0006 says polling only in v1. Confirm.
- **Decision:** Confirmed. No APNs push in v1. Polling + local notifications from BGAppRefreshTask is the full notification model. ADR-0006 stands. Close OPEN-01.
- **Follow-up:** Close OPEN-01 in `open-issues.md`.

### Q-041 — Poll targets
- **Status:** DECIDED
- **Context:** Currently Discourse totals only. Also ToDos / News?
- **Code state:** Discourse notification totals only.
- **Docs state:** FR-NOTIF-001 mentions Discourse only.
- **Decision:** Background task polls all volatile inputs: Forum (Discourse notifications), News, Messages (Discourse PMs), ToDos, Knowledge (Kanon SHA check), and Events/Calendar. Each runs independently so a failure in one does not block others.
- **Follow-up:** Update FR-NOTIF in `requirements.md` to list all six poll targets. Update ADR-0006. Flag to Claude Code: extend `BackgroundTaskScheduler` to cover all six sources.

### Q-042 — Per-category notification toggles
- **Status:** DECIDED
- **Context:** Code has granular toggles; docs only mention PMs + forum.
- **Code state:** Per-category toggles exist in Profile screen.
- **Docs state:** FR-PROF-002 mentions only PMs and forum activity.
- **Decision:** All six categories are toggleable: Forum, Messages, News, ToDos, Knowledge updates, and Events/Calendar. Each toggle determines whether new activity in that category triggers a local push notification (banner + sound). Polling always runs in the background regardless of toggle state; the toggle only gates whether a notification is displayed.
- **Follow-up:** Update FR-PROF-002 in `requirements.md` to list all six categories. Update FR-NOTIF accordingly.

---

## Home (Kajüte)

### Q-043 — "Meinung, egal wozu" widget (OPEN-04)
- **Status:** DECIDED
- **Context:** Destination of the thumbs-up / thumbs-down feedback widget undefined.
- **Code state:** Sends a Discourse private message to @sebulino.
- **Docs state:** OPEN-04 open.
- **Decision:** Sending a Discourse PM to @sebulino is the intended behaviour for v1. Close OPEN-04.
- **Follow-up:** Close OPEN-04 in `open-issues.md`. Document in FR-HOME-003 in `requirements.md` that feedback is sent as a Discourse PM to the app maintainer.

### Q-044 — "Weiterlesen" module
- **Status:** DECIDED
- **Context:** Selection logic for the 3-5 Kanon entries shown on the Kajüte.
- **Code state:** Unknown / unclear selection logic.
- **Docs state:** FR-HOME-004 says "3–5 curated Kanon entries the user has not yet read".
- **Decision:** Show the last 3–5 Kanon entries the user has already read, sorted by last-read date descending (most recently read first). This is a "recently read" / "continue here" list, not a recommendations list. Reading progress is already tracked in `ReadingProgressStore`.
- **Follow-up:** Update FR-HOME-004 in `requirements.md` to reflect this. Flag to Claude Code: update the Kajüte selection logic to read from `ReadingProgressStore` sorted by last-read date.

### Q-045 — "Letzte Kontakte"
- **Status:** DECIDED
- **Context:** Backed by `RecentRecipientsStore`; per-device only. Good enough?
- **Code state:** Manually maintained store, populated when user sends a DM.
- **Docs state:** Not specified in detail.
- **Decision:** Derive "Letzte Kontakte" from the Discourse message thread list fetched on app open. Extract the list from the cached message data and read locally without additional API calls. No separate `RecentRecipientsStore` needed — source of truth is `DiscourseCacheStore.messageThreads`.
- **Follow-up:** Update FR-HOME-002 in `requirements.md`. Flag to Claude Code: derive "Letzte Kontakte" from `DiscourseCacheStore.messageThreads` instead of maintaining a separate store.

---

## Profile

### Q-046 — `UserProfileView` for other members
- **Status:** DECIDED
- **Context:** Not in requirements yet. Add?
- **Code state:** `UserProfileView` implemented, showing Discourse user card.
- **Docs state:** Not mentioned.
- **Decision:** Add as a Must requirement for v1. Reachable from: tapping a post author in the Forum, tapping a message author in Nachrichten, tapping a contact in "Letzte Kontakte" on the Kajüte.
- **Follow-up:** Add FR-PROF-005 to `requirements.md`: "Tapping any member's name or avatar opens their profile (Discourse user card: avatar, username, join date, post count)."

### Q-047 — Feedback compose / admin request
- **Status:** DECIDED
- **Context:** Present in code, absent from docs.
- **Code state:** `FeedbackComposeView` and `AdminRequestView` both implemented.
- **Docs state:** Not mentioned.
- **Decision:** Both are intentional v1 features. Add to requirements.
- **Follow-up:** Add to `requirements.md` under Profile: FR-PROF-006 "User can compose and send feedback to the app maintainer." FR-PROF-007 "User can request admin privileges on meine-piraten.de via the in-app form (POST /admin_requests.json)."

### Q-048 — Data export / text selection (FR-PROF-004, "Could")
- **Status:** DECIDED
- **Context:** Added speculatively to initial requirements, not requested. However, text selection within the app is a real requirement.
- **Code state:** `SelectableTextView` (UIViewRepresentable) exists. Not confirmed applied consistently.
- **Docs state:** FR-PROF-004 (Could) — wrong framing.
- **Decision:** Remove FR-PROF-004 (data export link). Replace with a new NFR: text in forum posts, Kanon entries, news items and messages must be selectable and copyable by the user.
- **Follow-up:** Delete FR-PROF-004. Add NFR-013 "All body text (forum posts, Kanon entries, news, messages) must be selectable and copyable." Flag to Claude Code: audit all content views for consistent use of `SelectableTextView`.

---

## Build / release / ops

### Q-049 — Versioning
- **Status:** DECIDED
- **Context:** Marketing version `1.0`, build `17`. Release candidate or dev?
- **Code state:** Marketing version stuck at `1.0` from Xcode default; build number is the real counter.
- **Docs state:** Silent.
- **Decision:** Marketing version `1.0` is a legacy artefact and cannot be rolled back. Build number is the meaningful version counter going forward. Still in active development — not a release candidate.
- **Follow-up:** Note in `README.md` that build number is the authoritative version indicator until a post-1.0 marketing version is set.

### Q-050 — CI/CD (OPEN-06)
- **Status:** DECIDED
- **Context:** GitHub Actions now or later?
- **Code state:** No pipeline. `CI_NOTES.md` documents commands only.
- **Docs state:** OPEN-06 open.
- **Decision:** GitHub Actions pipeline, running on every PR and push to main: build + tests + lint.
- **Follow-up:** Keep OPEN-06 open, update it with the concrete scope (build + tests + lint via GitHub Actions). This is a code/infra task, not a docs task.

### Q-051 — Lint / format
- **Status:** DECIDED
- **Context:** SwiftLint / SwiftFormat — v1 or later?
- **Code state:** Neither configured.
- **Docs state:** Silent.
- **Decision:** Both SwiftLint and SwiftFormat. SwiftLint enforces style and correctness rules; SwiftFormat auto-formats code. Both run in CI.
- **Follow-up:** Add `.swiftlint.yml` and `.swiftformat` config files as a code task. Update OPEN-06 to include lint + format in the CI pipeline spec.

### Q-052 — `Secrets.sample.xcconfig`
- **Status:** DECIDED
- **Context:** Missing; README references it.
- **Code state:** File absent.
- **Docs state:** Silent.
- **Decision:** Create `Config/Secrets.sample.xcconfig` with all required keys and safe placeholder values. Simultaneously fix naming consistency (Piragitator → Agitatorrr) and remove unused Telegram keys.
- **Follow-up:** Claude Code prompt prepared in `prompt-q052-naming-and-sample-config.md`.

### Q-053 — `.build/` hygiene
- **Status:** DECIDED
- **Context:** `.build/` is untracked but not gitignored.
- **Decision:** Add `.build/` to `.gitignore`.
- **Follow-up:** Claude Code one-liner: add `.build/` to `.gitignore`.

### Q-054 — TestFlight / Ad-hoc / App Store strategy
- **Status:** DECIDED
- **Context:** How will the app reach members?
- **Decision:** TestFlight for initial distribution, App Store as the target for public release.
- **Follow-up:** Note in `README.md`. App Store submission requirements (privacy policy, app description, screenshots) are a pre-release task, not tracked here.

### Q-055 — Telemetry / crash reporting
- **Status:** DECIDED
- **Context:** Docs say "none". Confirm.
- **Decision:** No telemetry or crash reporting in v1. Crash reporting will be evaluated post-v1. Service choice (Sentry self-hosted or alternative) to be decided then, with a privacy review.
- **Follow-up:** Keep NFR-007 as-is for v1. Add a post-v1 note that crash reporting is planned.

---

## Security & privacy

### Q-056 — Existing `THREAT_MODEL.md`
- **Status:** DECIDED
- **Context:** Merge into new docs structure, keep separate, or deprecate?
- **Decision:** Merge into the new documentation structure as `docs/threat-model.md`. To be reviewed regularly — at minimum before each major release.
- **Follow-up:** Add `threat-model.md` to the docs folder. Copy and adapt content from the existing `Docs/THREAT_MODEL.md`. Add a "Last reviewed" date field at the top. Reference it from `docs/README.md`.

### Q-057 — `LogRedactor` adoption
- **Status:** DECIDED
- **Context:** Helper exists but is sparsely used. Mandate it?
- **Decision:** Mandatory. Any log message that could contain user data, tokens, or PII must pass through `LogRedactor`. This is a code review rule and an architecture requirement.
- **Follow-up:** Add to `architecture.md` under the Logger section. Flag to Claude Code: audit all logging call sites for missing `LogRedactor` usage.

### Q-058 — Telegram bot token in local `Secrets.xcconfig`
- **Status:** DECIDED
- **Context:** No Telegram feature in the app. Purpose?
- **Decision:** The token belongs to the meine-piraten.de backend, not the app. It ended up in the local config by accident. Remove `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` from `Secrets.xcconfig`. Already included in the Claude Code prompt for Q-052.
- **Follow-up:** Covered by `prompt-q052-naming-and-sample-config.md`.

---

## Documentation & content

### Q-059 — Existing `Docs/` files
- **Status:** DECIDED
- **Context:** 10 pre-existing Markdown files in repo `Docs/` folder.
- **Decision:** All ten merged into the new docs structure. Originals in `Docs/` deleted after merge.
- **Merge map:**
  - `DECISIONS.md` → content folded into relevant ADRs
  - `PROJECT_STATUS.md` → merged into `README.md`
  - `RELEASE_CHECKLIST.md` → new `docs/release-checklist.md`
  - `PUSH_NOTIFICATIONS_RAILS_PRD.md` → merged into ADR-0006 and `open-issues.md`
  - `API_REQUEST_MAP.md` → merged into `integrations.md`
  - `OPEN_QUESTIONS.md` → folded into `open-issues.md`
  - `Wissen-Tab-Darstellungskonzept.md` → merged into `requirements.md` Wissen section
  - `CI_NOTES.md` → merged into `open-issues.md` OPEN-06
  - `NOTIFICATIONS_TODO.md` → merged into ADR-0006 and `open-issues.md` OPEN-12
  - `THREAT_MODEL.md` → new `docs/threat-model.md` (Q-056)
- **Note:** Before merging, each source file must be reviewed for content that contradicts or extends decisions made in this log. Consistency with the new docs is required — do not merge blindly.

### Q-060 — `CLAUDE.md` and `scripts/ralph/`
- **Status:** DECIDED
- **Context:** Dev-tool artefacts for an autonomous agent. In repo but partially gitignored.
- **Decision:** Remove. Clean up all unused tool artefacts from the codebase.
- **Follow-up:** Claude Code task: delete `scripts/ralph/`, `CLAUDE.md`, and any related entries from `.gitignore`. Verify nothing else references these paths.

### Q-061 — `README.md` freshness
- **Status:** DECIDED
- **Context:** Stale claims (Forum replies "not started", ToDos fake data, etc.).
- **Decision:** Rewrite README.md to accurately reflect current implemented state.
- **Follow-up:** Claude Code prompt prepared in `prompt-q061-readme-update.md`.

---

## Contribution & governance

### Q-062 — `CONTRIBUTING.md`
- **Status:** DECIDED
- **Context:** Write now or wait for first external contributor?
- **Decision:** Deferred. Write when the first external contributor appears. A Claude Code prompt will be prepared at that point.
- **Follow-up:** None now.

### Q-063 — Code of Conduct
- **Status:** DECIDED
- **Context:** Necessary for open-source release with party affiliation?
- **Decision:** Deferred. To be evaluated when the project goes public and based on actual community need.
- **Follow-up:** None now.

### Q-064 — Issue / PR templates
- **Status:** DECIDED
- **Context:** GitHub issue and PR templates — now or later?
- **Decision:** Now. Bug report, feature request, and PR template.
- **Follow-up:** Claude Code prompt prepared in `prompt-q064-github-templates.md`.

### Q-065 — Eager vs lazy validation of the Discourse User-Api-Key at app launch
- **Status:** DECIDED 2026-05-21
- **Context:** The Android sibling app pings Discourse (`/categories.json`)
  at startup to validate the User-Api-Key. If invalid, it triggers re-auth
  immediately, before the user encounters the dead key inside a Discourse-
  dependent flow. iOS currently relies on implicit validation: the
  `DiscourseNotificationPoller.poll()` call at first appearance of
  `MainTabView` hits an authenticated endpoint; `DiscourseHTTPClient`
  clears the credential on 401/403; and `ForumView.task` re-triggers the
  handshake when the user lands on the Forum tab. The remaining gap: a
  user with a dead key who never visits Forum/Messages doesn't see the
  re-auth prompt until they do.
- **Decision:** Do nothing for v1. The implicit path covers the common
  case. Eager validation would add either an explicit `/session/current.json`
  call at launch (Option C in the analysis) or a published "credential
  cleared" event observed by `RootView` (Option B). Neither is worth the
  complexity until there is user feedback that the current behaviour is
  noticeable / annoying.
- **Reversal trigger:** Tester or user feedback that the re-auth prompt
  appears too late (e.g., "tapped Forum, had to wait for auth before
  reading anything"). On that signal, revisit and most likely implement
  Option B (publish-and-observe on credential clear, no extra network
  call) — that's the lowest-cost variant that closes the gap.
- **Follow-up:** None now. Note added to `Docs/adr/0009-discourse-user-api-key.md`
  context section so the design choice is visible alongside the auth
  flow itself.

### Q-066 — Bell badge vs Kajüte counter: should likes be counted alike?
- **Status:** DECIDED 2026-05-27
- **Context:** The toolbar bell badge polls Discourse's
  `/notifications/totals.json` endpoint, which returns `unread_notifications` —
  the count of **all** unread Discourse notifications regardless of type
  (likes, replies, mentions, watched-topic updates, new messages, …).
  The Kajüte "Du hast X neue Nachrichten" line counts only inbox threads
  where `isRead == false` — i.e., threads where there is actually a new
  *message* to read. The two counters can diverge, e.g. a like on one of
  your own posts increments the bell badge but not the Kajüte counter.
  Question raised during the screenshot review of PR #81: should a like
  also mark its parent thread as unread, so the two counters stay in
  sync?
- **Decision:** No. Keep the current behaviour. A like is a reaction to
  existing content, not new content — flipping `isRead` would put the
  thread back into the "needs your attention" pile even though there is
  literally nothing new to read in it. The bell badge and the Kajüte
  line measure different things on purpose: the bell says "something
  on Discourse changed for you" (broad), the Kajüte line says "someone
  is waiting for your reply" (narrow). This is the same separation
  Twitter, Slack, and Discourse-web themselves use.
- **Reversal trigger:** Pilot-user feedback that the divergence is
  confusing. Plausible v1.1 mitigation would NOT be to merge the two
  counters but to add a dedicated "👍 3 Likes diese Woche" block in the
  Kajüte — that turns the otherwise-invisible like notifications into
  a positive signal rather than counter inflation.
- **Follow-up:** None. The `DiscoursePrivateMessageTopicDTO.computeIsRead()`
  helper (added in PR #81) intentionally does not check for like events;
  comment in the DTO file makes that explicit.

### Q-067 — Background notification latency: optimise pre-submit or wait for feedback?
- **Status:** DECIDED 2026-05-27
- **Context:** Real-world observation during pre-submit testing: a
  Discourse private message arrived, but no iOS local notification fired
  until the app was opened ~10 min later (it appeared immediately on
  open). The app is **polling-based** (no APNs/FCM push by design — see
  `Docs/datenschutz.md` Abschnitt 4.7). Background polling runs through
  `BGAppRefreshTask` registered in `BackgroundTaskScheduler` with
  `earliestBeginDate = +30 min`. iOS treats `earliestBeginDate` as a
  *minimum*, not a schedule — actual fire frequency depends on user
  patterns, battery, Low Power Mode, system load, and ~6 other
  heuristics. For a freshly-installed app iOS may not fire the task at
  all for the first 1–3 days while it learns usage patterns. **No code
  change can shorten this** below what iOS decides; lowering
  `earliestBeginDate` to e.g. 5 min would not change behaviour.
- **Decision:** Ship v1.0 with the current polling-only approach.
  Collect real-world feedback from members during/after the App Store
  rollout before investing in latency improvements. The privacy
  trade-off (no third-party server sees message metadata) is a
  deliberate v1 stance and matches the Android sibling's behaviour.
- **Reversal trigger:** ≥3 independent member reports that "I missed a
  message because it appeared too late" within the first month of v1.0
  in the App Store, OR any single report of a time-critical message
  (e.g. internal vote with deadline) being missed because of polling
  latency.
- **Follow-up options if triggered, in escalating invasiveness:**
  1. **Foreground-aggressive polling** — when the app is open in the
     Forum/Nachrichten tab, poll every 60s instead of relying on the
     coarse staleness guard. Privacy: 100% preserved. Helps the
     "app-open-in-pocket" case but not the truly-backgrounded case.
  2. **Background URL Session silent ping** — server fires an
     APNs silent-push (`content-available: 1`, no body) when something
     changes. App wakes up, polls itself, emits its own local
     notification. Apple sees only "wake the app", not content. Needs
     a small server-side component (Discourse webhook → APNs).
  3. **Full APNs push with content** — instant, requires server-side
     push + sees message metadata at Apple. Largest privacy delta;
     would need an ADR amendment + datenschutz.md update.
- **Tracking issue:** filed in the iOS repo so member reports have a
  single thread to land in.
