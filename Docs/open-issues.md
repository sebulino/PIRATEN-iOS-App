# Open Issues

Things that are known to be unresolved. Each is numbered stably so that ADRs,
commit messages and issues can reference them. Resolved items are kept
(struck through) with a pointer to the resolving ADR / Q-decision.

---

## OPEN-02 — Likes do not sync to Discourse

**Status:** RESOLVED 2026-04-22 — implementation in
[ADR-0014](./adr/0014-like-strategy-chain.md). End-to-end verification on
the live instance is pending TestFlight observation.

**Context.** Posting `POST /post_actions.json` from the app did not
propagate the like to the Discourse server. The like was displayed
optimistically on the device only. Prior investigation paths failed:

- Analysis of the official Discourse mobile app yielded no insights.
- Following the API documentation did not produce a working request.

**Resolution summary.** Built a strategy chain
(`PIRATEN/Core/Data/Discourse/LikeStrategy.swift`) that probes three
likely endpoints in order — discourse-reactions plugin, form-encoded
`/post_actions.json`, JSON `/post_actions.json` — and caches the
winning strategy in UserDefaults under `discourse_like_winning_strategy`.
Confirmation is body-content based, so Discourse's silent-2xx no-op
signature (the OPEN-02 fingerprint) is detected as a soft failure and
the chain falls through to the next strategy. Hard 4xx/5xx errors abort
the chain so genuine auth or network failures are still surfaced.

**Verification follow-up before App Store submission:**

- Tap a like in TestFlight; reload the topic from a separate Discourse
  client and confirm the like appears.
- Read `UserDefaults.standard.string(forKey: "discourse_like_winning_strategy")`
  on a debug build to identify which strategy won. Once known across
  multiple test devices, narrow `LikeStrategyRegistry.all` to that
  single strategy and remove the others.

---

## OPEN-06 — CI pipeline

**Status:** OPEN — target before v1 ship

**Context.** NFR-011 requires a fresh-checkout build. A CI pipeline that
actually enforces this does not exist yet.

**Scope (Q-050, Q-051):**

- GitHub Actions workflow running on every pull request and push to `main`.
- Build (`xcodebuild` for iOS 26.2 simulator).
- Tests (unit + UI).
- Lint: SwiftLint.
- Format check: SwiftFormat.

`.swiftlint.yml` and `.swiftformat` config files need to be added.

---

## OPEN-09 — `handleAuthenticationError()` is disabled

**Status:** RESOLVED 2026-05-18 — handler re-enabled with proper
semantics. Real-device verification pending before App Store
submission.

**Context.** `AuthStateManager.handleAuthenticationError()` was disabled
in commit `6f4b73b` (2026-02-01) at the same time that Discourse User
API Key auth (ADR-0009) landed. The original handler was generic
"any 401/403 → logout", which incorrectly wiped valid PiratenSSO
sessions when a Discourse User API Key got revoked (a separate auth
concern). The quick fix at the time was to pass `onAuthError: nil` to
the Discourse HTTP client and disable the handler "since no one calls
it anymore".

Later, commit `209bfb2` re-wired the meine-piraten.de Todo HTTP client
to call the (now disabled) handler. Commit `ab2578e` (2026-03-23)
added a workaround in `TodosViewModel.loadTodos()` that caught
`TodoError.unauthorized` directly and called
`authStateManager?.logout()` — bypassing the dead handler entirely.

Net effect: a fragile pattern where every ViewModel touching
meine-piraten.de had to remember to catch auth errors itself, while
the central handler infrastructure (single-attempt guard,
`AuthState.sessionExpired` case, `SessionExpiredView`) sat unused.

**Resolution summary.** `handleAuthenticationError()` re-enabled with
the original M3B-006 semantics now intentional rather than dead:

1. Single-attempt guard (`isHandlingAuthError`) so a burst of
   simultaneous 401s from parallel API calls triggers exactly one
   logout transition.
2. Calls `authRepository.logout()` + clears recent-recipients cache.
3. Transitions to `.sessionExpired` (distinct from `.unauthenticated`
   so `RootView` routes to `SessionExpiredView` with a clear "session
   expired" message instead of the initial-launch login screen).
4. Guard is reset on successful `authenticate()` or explicit `logout()`.

The 401/403 distinction in `AuthenticatedHTTPClient` is left as-is:
both still trigger `onAuthError`. On meine-piraten.de — the only
SSO-Bearer-authed surface — a 403 to an authenticated user
essentially does not occur (per project owner's confirmation), and
the `TodoAPIError` layer already collapses both status codes to
`.unauthorized` anyway. Distinguishing them in the HTTP client would
be dead-code distinction that no caller observes.

The workaround in `TodosViewModel.loadTodos()` is removed (silent
catch instead — the central handler is already transitioning the
auth state). The now-unused `authStateManager` parameter is removed
from `TodosViewModel.init`.

Discourse-side auth (User API Key revocation) is unchanged — it
continues to flow through `DiscourseHTTPClient` clearing the
credential, separate from this handler, per ADR-0009.

**Verification follow-up before App Store submission:**

- Revoke or expire the PiratenSSO session manually, exercise a
  meine-piraten.de API call (e.g. open Aufgaben tab) on a real
  device, confirm `SessionExpiredView` is shown.
- Trigger multiple concurrent API calls when the session is invalid
  (e.g. on cold launch from the Home dashboard which fans out to
  several endpoints) and confirm exactly one logout transition fires,
  not one per failing request.
- After re-authenticating, confirm the single-attempt guard resets
  correctly (re-trigger an auth failure, ensure it transitions to
  `.sessionExpired` again rather than silently no-op'ing).

---

## OPEN-10 — Move Kanon repo to piratenpartei org

**Status:** OPEN — not a v1 blocker

**Context.** The Kanon lives at `sebulino/PIRATEN-Kanon`, a personal repo.
For long-term party ownership it should move to the `piratenpartei`
GitHub organisation.

**Next step.** Arrange the transfer. Once moved, update
`KNOWLEDGE_REPO_OWNER` in `Config/Secrets.xcconfig` (no code change
required — the value is already configurable).

---

## OPEN-11 — Kanon authoring schema

**Status:** OPEN — not a v1 blocker but needed for external contributors

**Context.** The Kanon uses a specific frontmatter format and typed
section blocks (callouts, checklists, quiz questions, …). Today the only
specification is the parser code (`FrontmatterParser.swift`,
`ContentSectionParser.swift`). External authors cannot contribute without
reading Swift.

**Next step.** Write `AUTHORING.md` in the Kanon repo covering:

- required and optional frontmatter fields,
- all supported section block types with examples,
- quiz question format,
- level and category values.

---

## OPEN-12 — Background task does not dispatch local notifications

**Status:** RESOLVED 2026-04-22 — implementation in
[ADR-0015](./adr/0015-background-notification-coordinator.md).
End-to-end verification on a real device (TestFlight) is pending; the
simulator's `simctl push` path is not equivalent to a real
`BGAppRefreshTask` fire.

**Context.** Notification dispatch (`scheduleLocalNotification`) lived
inside SwiftUI `.onChange` observers in `MainTabView`, which only fire
while the view is rendered. When iOS wakes the app headless for a
`BGAppRefreshTask`, no view hierarchy exists; the observers never fire.
Additionally the background poll only hit Discourse's aggregate-totals
endpoint, so Todos, News, Knowledge, and Events were never checked at
all.

**Resolution summary.** Introduced
`PIRATEN/Core/Data/Notifications/BackgroundRefreshCoordinator.swift`, a
plain `@MainActor` object invoked from
`BGAppRefreshTask.handleAppRefresh`. Polls all six sources (Forum,
Messages, Todos, News, Knowledge, Events) in parallel via `TaskGroup`;
each child has its own `do/catch` so one source failing does not block
the siblings. Per-source persisted markers (`bg_*_last_seen_*` in
UserDefaults) detect new activity. For each source with new activity
and an enabled `NotificationSettingsManager` toggle, a notification is
dispatched via the new shared `LocalNotificationScheduler`. The same
scheduler is also called from the foreground `.onChange` observers so
in-view and headless paths use identical titles/bodies.
`NotificationSettingsManager` extended with `knowledgeEnabled` and
`eventsEnabled` to reach the six categories FR-PROF-002 specifies.

**Verification follow-up before App Store submission:**

- Background the app, post fresh content from another device in each
  of the six categories, confirm a banner arrives for every category
  the user has enabled in Profile.
- Confirm `BackgroundRefreshCoordinator.reset()` fires on logout (see
  ADR-0015 follow-ups).

---

## Resolved

- ~~OPEN-01 — Push notifications~~ — resolved by Q-040: polling only in v1;
  ADR-0006 stands. APNs is explicitly out of scope.
- ~~OPEN-03 — ToDo API contract~~ — resolved by Q-033: API is documented at
  <https://meine-piraten.de/api>.
- ~~OPEN-04 — "Meinung, egal wozu" destination~~ — resolved by Q-043:
  sends a Discourse PM to @sebulino.
- ~~OPEN-05 — Licence choice~~ — resolved by Q-004: EUPL-1.2.
- ~~OPEN-07 — Discourse auth path~~ — resolved by Q-013 and ADR-0009:
  User API Key flow.
- ~~OPEN-08 — Quiz progress storage~~ — resolved by Q-028:
  `ReadingProgressStore` in UserDefaults, device-local, keyed per
  PiratenSSO `sub`.
