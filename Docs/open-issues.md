# Open Issues

Things that are known to be unresolved. Each is numbered stably so that ADRs,
commit messages and issues can reference them. Resolved items are kept
(struck through) with a pointer to the resolving ADR / Q-decision.

---

## OPEN-02 — Likes do not sync to Discourse

**Status:** RESOLVED 2026-05-20 — verified end-to-end on real device.
Like persists server-side, visible from web Discourse.

**Context.** Posting from the app did not propagate the like to the
Discourse server. The like was displayed optimistically on the device
only. Prior investigation paths failed:

- Analysis of the official Discourse mobile app yielded no insights.
- Following the API documentation did not produce a working request.

**Root cause (after six iterations of wrong theories — see
ADR-0014).** `HTTPRequest.post(_:body:headers:)` in
`PIRATEN/Core/Domain/HTTP/HTTPClient.swift` was overriding the
caller's `Content-Type` unconditionally to `application/json`. The
`postActionLike` code path correctly set
`Content-Type: application/x-www-form-urlencoded; charset=UTF-8`
in its headers dict, but the moment that dict was passed into
`.post()`, the value was clobbered. The wire request shipped with a
form-encoded body and `Content-Type: application/json`, Rails' JSON
body parser failed to parse the form-encoded bytes, and the request
400ed with an empty body before reaching Discourse's
`PostActionsController`.

The five earlier theories chased and discarded:

1. `.json` URL suffix activating `wrap_parameters` — bare path still
   400ed.
2. `Accept: application/json` triggering JSON format detection — `*/*`
   still 400ed.
3. Session cookies from the `/user-api-key/new` handshake leaking
   into URLSession — cookies disabled, still 400ed.
4. HTTP/2 transport differences — Discourse's nginx ALPN-negotiates
   HTTP/1.1 regardless.
5. URLSession auto-injecting unexpected headers — captured via
   `URLSessionTaskMetrics`, which immediately revealed the
   `Content-Type: application/json` we hadn't expected to find.

The factory method's bug was visible the moment we could see the
exact headers URLSession sent on the wire. Earlier iterations missed
it because we were only logging the headers we set on the
`URLRequest`, not what `URLSession`/`CFNetwork` actually transmitted.

**Resolution.** Two-line change to
`HTTPRequest.post(_:body:headers:)`: the factory now only defaults
`Content-Type` to `application/json` if the caller has not set one
explicitly. Every other caller of `.post(...)` keeps working because
they never set Content-Type themselves; the `postActionLike`
form-encoded path now works because its explicit value is preserved.

The strategy chain machinery (`LikeStrategy.swift`) remains as
documented in [ADR-0014](./adr/0014-like-strategy-chain.md) — it
turned out not to be the fix, but the chain's "probe → cache →
learn" framing was useful for hypothesis testing, and the
single-strategy registry is now operating as a thin wrapper that
can be removed in a future cleanup pass.

The DELETE unlike URL was also cleaned of its `.json` suffix to
match the like path and the web UI for consistency.

**Lessons captured for future debugging:**

- When two clients (curl and URLSession) disagree on whether the
  same request is rejected, dig into the actual on-the-wire bytes
  *first*, before speculating about request shape. `URLSessionTaskMetrics`
  is the right tool.
- Any factory method that mutates request shape (headers, body, URL)
  needs to be transparent about it — naming and behavior. The
  `.post()` factory's name didn't suggest it was *enforcing* JSON
  over caller-provided headers. Consider renaming `.post()` to
  `.postJSON()` and adding a separate `.postForm()` in a future pass.

---

## OPEN-06 — CI pipeline

**Status:** RESOLVED 2026-05-20 — initial CI pipeline shipped.
Phased strictness: lint and format check are warn-only at first; flip
to blocking after a single bulk cleanup pass.

**Resolution summary.** Three new files at the repo root:

- `.github/workflows/ci.yml` — runs on every PR and push to `main`.
  Builds the app for a generic iOS Simulator destination, runs unit
  tests (PIRATENTests only) on an iPhone 16 simulator, and runs
  SwiftLint + SwiftFormat as separate non-blocking jobs.
- `.github/workflows/ui-tests.yml` — runs the PIRATENUITests target
  on a booted simulator. Excluded from the per-PR loop because of
  flakiness and ~10-15 min runtime. Triggers: manual dispatch +
  nightly at 03:00 UTC against `main`.
- `.swiftlint.yml` — minimal opinionated config (a few opt-in rules
  catching real bugs like `empty_count`, `first_where`,
  `unused_import`; verbose style rules like `line_length` /
  `cyclomatic_complexity` deliberately disabled until the bulk
  cleanup pass).
- `.swiftformat` — records project style choices (4-space indent,
  Swift 5.10, soft 140-col line target) without enforcing a one-shot
  reformat of the existing codebase.

**Follow-ups documented for the bulk cleanup pass:**

- Reformat the codebase once with `swiftformat .` and review the
  diff before committing.
- Drive SwiftLint warning count to zero (one cleanup PR, no behavior
  changes).
- Remove `continue-on-error: true` from both the `lint` and `format`
  jobs in `ci.yml` to make them blocking checks.
- Consider tightening `.swiftlint.yml` (re-enable `line_length`,
  `function_body_length`, etc.) after the bulk pass.

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

**401 vs 403** in `AuthenticatedHTTPClient` is now distinguished per
the meine-piraten.de API contract (<https://meine-piraten.de/api>):

- **401** (missing/invalid/expired token) → triggers `onAuthError` →
  central session-expiry transition.
- **403** (valid token, insufficient permissions) → throws
  `HTTPError.forbidden` without invoking the central handler. The
  user keeps their session and the caller surfaces the permission
  error to the UI.

Per the project owner's confirmation, 403 is rare in practice on
meine-piraten.de because most user actions are permitted when SSO is
valid — but the distinction is required because the access token TTL
is only 5 minutes and 401s for token expiry need to flow through the
single-attempt guard cleanly, while a 403 from a permission boundary
must NOT log the user out.

`AuthStateManager.getValidAccessToken()` now routes through the same
`handleAuthenticationError()` path when the local refresh fails
(refresh token revoked/expired), rather than inlining its own
`.unauthenticated` transition. The single-attempt guard therefore
covers both failure modes:

- Local refresh fail in `getValidAccessToken()`
- Server-side 401 reaching `AuthenticatedHTTPClient`

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
