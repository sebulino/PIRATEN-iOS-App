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

**Status:** OPEN — target before v1 ship

**Context.** `AuthStateManager.swift:128` has a published auth-error
handler that is intentionally inert — it prints a warning and does
nothing. The reason for the disabling is unknown.

**Next step.** Investigate: what triggers this code path, why it was
disabled, and what the correct behaviour should be (force logout / show
error screen / silent retry).

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

**Status:** OPEN — **blocker for v1 ship** (FR-NOTIF-004)

**Context.** The code to dispatch local iOS notifications
(`scheduleLocalNotification`) is wired to SwiftUI `.onChange` observers
in `MainTabView`, which only fire while the app is running. When the
`BGAppRefreshTask` fires in the background, it polls the APIs and updates
the aggregate badge — but no banner notification is delivered, even if the
user has enabled that category in Profile.

**Next step.** Move the notification dispatch logic out of SwiftUI
observers and into the background task handler in
`BackgroundTaskScheduler`. The handler should:

1. Poll each of the six sources (Forum, Messages, News, ToDos, Knowledge,
   Events).
2. For each source with new activity, check whether the user has enabled
   notifications for that category.
3. If enabled, schedule a `UNMutableNotificationContent` via
   `UNUserNotificationCenter.current().add(...)`.

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
