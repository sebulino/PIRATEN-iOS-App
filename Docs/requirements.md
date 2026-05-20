# Requirements — MeinePIRATEN iOS

**Document status:** Draft 0.2 · Owner: Sebastian Alscher · Language: English
(UI language: German)

This document reflects the decisions recorded in [`decisions-log.md`](./decisions-log.md).
Requirement IDs are stable. Do not renumber; add new ones at the end of a section.

---

## 1. Purpose and scope

MeinePIRATEN is a native iOS application for members of the Piratenpartei
Deutschland. Its purpose is to counteract the fragmentation of party
communication by providing a single, mobile-first entry point that makes the
Discourse forum at `diskussion.piratenpartei.de` reachable, readable and
actionable from a phone.

The app is **not** a replacement for Discourse. Discourse remains the backend
of record for discussion and knowledge (see [ADR-0002](./adr/0002-discourse-as-backend-of-record.md)).
The app is a reach layer that:

- makes Discourse content skimmable in 5-minute windows,
- surfaces party-wide context (events, news, tasks) that is currently scattered,
- onboards new members with structured introductory content,
- lets members see each other as a whole rather than as isolated messenger subgroups.

### 1.1 In scope (v1)

- Forum reading, writing (replies and new topics), reacting, private messaging — via Discourse.
- Knowledge section sourced from the [PIRATEN-Kanon](https://github.com/sebulino/PIRATEN-Kanon) GitHub repository.
- Event feed sourced from Agitatorrr (iCal).
- Volunteer task list ("ToDos") sourced from `meine-piraten.de`.
- News feed sourced from `meine-piraten.de/api/news`.
- Single sign-on via PiratenSSO.
- Polling-based notifications with local iOS banner dispatch.

### 1.2 Out of scope (v1)

- Web or Android clients.
- APNs push notifications (polling only, see [ADR-0006](./adr/0006-notifications-v1-polling.md)).
- Localisation / internationalisation (German-only in v1; i18n planned post-v1).
- iPad support (iPhone only).
- Authoring tooling for the Kanon or news feed — content is maintained elsewhere.
- Any feature that would make the app, rather than Discourse, the source of truth.
- Crash reporting / telemetry (evaluated post-v1).

---

## 2. Stakeholders and users

| Stakeholder | Interest |
|---|---|
| Party members (established) | Stay informed despite fragmentation; one-thumb access to what matters. |
| New members | Find the party, discover what is happening, learn the basics. |
| Volunteer coordinators | Reach critical mass for actions; fill ToDo slots. |
| Vorstand / working groups | Distribute announcements to a verifiably reachable audience. |
| PiratenSSO operators | Authoritative identity; must not be bypassed or mirrored. |
| Discourse admins | App-driven traffic must respect Discourse rate limits and moderation. |

### 2.1 Primary personas

- **"Five-minute Pia."** Opens the phone while on a tram. Wants to know whether
  anything new is worth reading. Almost never initiates a thread but will like
  and occasionally reply.
- **"Organiser Otto."** Runs a local chapter. Needs to publish events, recruit
  helpers for specific tasks, and see who is active in his region.
- **"New member Nele."** Just joined. Does not know the landscape yet. Needs
  orientation, easy wins, and a sense that the party is alive.

---

## 3. Functional requirements

### 3.1 Authentication (AUTH)

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-AUTH-001 | Must | Users authenticate via **PiratenSSO** (OAuth 2.0 / OIDC, Authorisation Code with PKCE). No local passwords. |
| FR-AUTH-002 | Must | The app must obtain a Discourse User API Key after PiratenSSO login (see [ADR-0009](./adr/0009-discourse-user-api-key.md)) so the user acts as themselves on Discourse. |
| FR-AUTH-003 | Must | Tokens are stored in the iOS **Keychain** with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, not in `UserDefaults` or files. Tokens do not survive device migration; users re-authenticate on a new device. |
| FR-AUTH-004 | Must | The app must handle token refresh transparently and route users to a re-login screen on irrecoverable failure. |
| FR-AUTH-005 | Should | A user can log out, which revokes the Discourse session if the API allows and clears all Keychain entries. |
| FR-AUTH-006 | Could | Support biometric re-authentication (Face ID / Touch ID) to unlock the app after backgrounding. (Deferred to post-v1.) |

#### Extended specs — Authentication

##### FR-AUTH-001 — PiratenSSO login

**User goal.** As a member, I want to sign in once with my PiratenSSO
credentials and have the app trust the same identity I already use
for Discourse and meine-piraten.de, so I don't have to manage
app-specific passwords.

**Acceptance criteria.**

- The launch screen shows a single "Mit PiratenSSO anmelden" button.
- Tapping it opens an `ASWebAuthenticationSession` against the
  PiratenSSO realm (Keycloak).
- The flow uses OAuth 2.0 Authorization Code with PKCE — no client
  secret, no resource-owner password grant.
- On success, access/refresh/ID tokens are persisted to the Keychain
  (FR-AUTH-003).
- Cancellation returns the user to the launch screen with no error.
- Authentication failure shows an actionable error message and a
  retry button.

**Platforms.**

| Platform | Status      | Notes                                                              |
|----------|-------------|--------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `AppAuthOIDCAuthService` (wrapper around openid/AppAuth-iOS SPM). |
| Android  | Not started | Same OAuth 2.0 + PKCE flow; AppAuth-Android library exists.       |

---

##### FR-AUTH-002 — Discourse User API Key handshake

**User goal.** As a member, after I sign in with PiratenSSO I want
the app to seamlessly become authenticated against the Discourse
forum without me having to re-enter credentials in a second flow.

**Acceptance criteria.**

- After PiratenSSO success and on first Forum-tab visit, the app
  automatically initiates Discourse's `/user-api-key/new` handshake
  (see [ADR-0009](./adr/0009-discourse-user-api-key.md) and #68).
- An RSA key pair is generated locally; the private key never leaves
  the device.
- The Discourse authorization page is presented in
  `ASWebAuthenticationSession` (browser-isolated; URLSession sees
  none of its cookies — see [ADR-0014](./adr/0014-like-strategy-chain.md)
  postscript for the cookie-leak lesson).
- The encrypted User API Key payload returned by Discourse is
  decrypted with the local RSA private key.
- The decrypted key is stored in the Keychain and used as
  `User-Api-Key` on every Discourse request thereafter.
- Cancellation puts the auth state machine in `.failed` (not
  `.idle`) so it doesn't auto-retry into a loop.

**Platforms.**

| Platform | Status      | Notes                                                                                |
|----------|-------------|--------------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `DiscourseAuthManager` + `RSAKeyManager`; auto-trigger via `ForumView.task` (#68). |
| Android  | Not started | Same wire protocol. BouncyCastle or AndroidX `KeyPairGenerator` for RSA.            |

---

##### FR-AUTH-003 — Secure Keychain storage

**User goal.** As a member, my session tokens must stay confined to
this specific device and this unlocked state — they should not
appear in encrypted backups that follow me to a new phone, nor be
readable when my phone is locked.

**Acceptance criteria.**

- All tokens (PiratenSSO access/refresh/ID; Discourse User API Key;
  Discourse client ID) are written via
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- No tokens are persisted to `UserDefaults`, the file system, or any
  iCloud-syncing storage.
- Keychain entries are removed on explicit logout (FR-AUTH-005).
- Keychain entries don't survive device migration (the
  `ThisDeviceOnly` accessible class enforces this).

**Platforms.**

| Platform | Status      | Notes                                                                                                              |
|----------|-------------|--------------------------------------------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `KeychainCredentialStore`, `KeychainDiscourseAPIKeyProvider`.                                                       |
| Android  | Not started | Equivalent: `EncryptedSharedPreferences` + AndroidX Security with `MasterKey`. Less strict per-device binding by default. |

---

##### FR-AUTH-004 — Transparent token refresh; hard failure routes to re-login

**User goal.** As a member, I want to stay logged in for everyday
use without re-authenticating every few minutes when the short-lived
access token rolls over — but if my session has truly ended (refresh
token revoked or expired) I want a clear path back to sign-in.

**Acceptance criteria.**

- PiratenSSO access tokens have a 5-minute TTL (per the API
  contract at <https://meine-piraten.de/api>).
- On expiry, the next outgoing request triggers an AppAuth-driven
  refresh using the stored refresh token. The user sees nothing.
- If the refresh succeeds, the request is retried transparently
  with the fresh token.
- If the refresh fails, the auth state transitions to
  `.sessionExpired` (distinct from `.unauthenticated` so the UI
  routes to `SessionExpiredView` with a "session expired" message
  rather than the initial-launch login screen).
- A single-attempt guard ensures a burst of parallel API calls
  hitting the same failed refresh fires exactly one logout
  transition.
- meine-piraten.de 401 (Bearer token rejected) routes through the
  same handler.
- meine-piraten.de 403 (valid token, insufficient permissions) does
  NOT trigger logout — it surfaces as a per-request error.

**Platforms.**

| Platform | Status      | Notes                                                                                                  |
|----------|-------------|--------------------------------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `AuthStateManager.handleAuthenticationError` (#72 / OPEN-09 fix). DEBUG-only "Simulate session expiry" button in Profile for verification. |
| Android  | Not started | AppAuth-Android handles refresh; same `.sessionExpired` state + single-attempt guard pattern needed. |

---

##### FR-AUTH-005 — Logout

**User goal.** As a member, I want a clear way to log out that wipes
my local credentials and returns the app to the launch state.

**Acceptance criteria.**

- A "Abmelden" button is visible in Profile.
- A confirmation dialog is shown before the action proceeds.
- On confirm: all Keychain entries (PiratenSSO + Discourse) are
  removed.
- In-memory user-specific state (recent recipients, cached profile
  data) is cleared.
- The app routes to the launch screen ready for a fresh PiratenSSO
  login.

**Platforms.**

| Platform | Status      | Notes                                                  |
|----------|-------------|--------------------------------------------------------|
| iOS      | ✅ Shipped  | `AuthStateManager.logout()` + Profile "Abmelden" button. |
| Android  | Not started | Same flow.                                             |

---

##### FR-AUTH-006 — Biometric re-authentication (deferred post-v1)

**User goal.** As a member with sensitive party communications, I
want the option to lock the app behind Face ID / Touch ID so a
brief device hand-off doesn't expose my Discourse messages.

**Acceptance criteria (target post-v1).**

- A setting in Profile enables biometric lock.
- When enabled, the app requires biometric authentication on cold
  launch and after returning from background (configurable idle
  threshold).
- Fallback to PiratenSSO re-auth if biometric is unavailable or
  fails repeatedly.
- No persistent unlock token — each session requires a fresh
  biometric prompt.

**Platforms.**

| Platform | Status   | Notes                                              |
|----------|----------|----------------------------------------------------|
| iOS      | Deferred | Post-v1. `LocalAuthentication.LAContext`.          |
| Android  | Deferred | Post-v1. AndroidX `BiometricPrompt`.               |

### 3.2 Kajüte — the home screen (HOME)

The *Kajüte* is the landing screen after login.

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-HOME-001 | Must | Greet the user by first name ("Ahoi \<Name\>!") and show whether there are unread private messages. |
| FR-HOME-002 | Must | Show "Letzte Kontakte" — recent people the user has exchanged DMs with. The list is derived from the cached Discourse message threads (no separate store); each contact is tappable to open the thread. |
| FR-HOME-003 | Should | Show a "Deine Meinung, egal wozu" module — a lightweight thumbs-up / thumbs-down feedback widget. Feedback is sent as a Discourse private message to the app maintainer (@sebulino). |
| FR-HOME-004 | Should | Show a "Weiterlesen" module with the last 3–5 Kanon entries the user has read, sorted by last-read date descending. Populated from `ReadingProgressStore`. |
| FR-HOME-005 | Should | Show "Übernommene Aufgaben" — the ToDos the user has personally taken on. |

#### Extended specs — Kajüte (home)

##### FR-HOME-001 — Greeting + unread-DM indicator

**User goal.** As a member opening the app, I want a quick, personal
acknowledgment ("Ahoi Sebastian!") and an at-a-glance view of whether
anyone is trying to reach me, so the app feels welcoming and I can
triage in 5 seconds.

**Acceptance criteria.**

- The greeting uses the user's first name from PiratenSSO claims.
- If first name is unavailable, falls back to handle.
- An unread-DM count is shown if greater than zero (small badge or
  inline text); zero is silent.
- The unread count is read from the same source the Messages tab
  badge uses, so the two are always consistent.

**Platforms.**

| Platform | Status      | Notes                                          |
|----------|-------------|------------------------------------------------|
| iOS      | ✅ Shipped  | `HomeView` greeting + `MessagesViewModel.hasNewContent`. |
| Android  | Not started | Same data sources; Compose `Text` for greeting. |

---

##### FR-HOME-002 — "Letzte Kontakte" derived from message cache

**User goal.** As a member, when I'm looking to reach a specific
person I've messaged recently I want to find them at the top of the
home screen without scrolling through every thread.

**Acceptance criteria.**

- A "Letzte Kontakte" row shows the last 5–10 distinct conversation
  partners.
- The list is derived purely from the cached Discourse message
  threads — there is **no separate** `RecentRecipientsStore` write
  path for this (FR-HOME-002 was specifically scoped to avoid that
  duplication).
- Each contact is tappable to open the corresponding message thread.
- Contacts are deduplicated (one row per person regardless of how
  many threads).

**Platforms.**

| Platform | Status                  | Notes                                                                |
|----------|-------------------------|----------------------------------------------------------------------|
| iOS      | In progress             | `RecentRecipientsStore` exists but should be deleted per this spec; the home-row should derive from `MessagesViewModel`'s cached threads instead. Tracked in the post-v1 cleanup pass. |
| Android  | Not started             | Derive same way from the Messages cache.                              |

---

##### FR-HOME-003 — "Deine Meinung, egal wozu" feedback widget

**User goal.** As a member who's noticed something nice or annoying
in the app, I want a one-tap way to let the maintainer know without
filing a GitHub issue or sending a Discourse DM manually.

**Acceptance criteria.**

- A small module shows a prompt ("Deine Meinung, egal wozu") with
  thumbs-up / thumbs-down + optional comment field.
- Submitting sends a Discourse private message to the maintainer
  (@sebulino) with the comment text and a sentiment tag.
- Submission shows a brief confirmation.
- The user can dismiss the module without sending.

**Platforms.**

| Platform | Status      | Notes                                                  |
|----------|-------------|--------------------------------------------------------|
| iOS      | ✅ Shipped  | `FeedbackViewModel` + `FeedbackComposeView`.          |
| Android  | Not started | Same Discourse PM API.                                |

---

##### FR-HOME-004 — "Weiterlesen" Kanon resume

**User goal.** As a member who started reading a Kanon entry but
didn't finish, I want a "continue reading" shortcut so I can pick up
where I left off without hunting through the knowledge browser.

**Acceptance criteria.**

- A module shows the 3–5 most recently opened Kanon entries.
- Sorted by last-read timestamp descending.
- Each row shows the entry title and a "last read X ago" timestamp.
- Tapping a row opens the entry at the location the user left off.
- Hidden when the user has no read history.

**Platforms.**

| Platform | Status                  | Notes                                                                                          |
|----------|-------------------------|------------------------------------------------------------------------------------------------|
| iOS      | Partial                 | `ReadingProgressStore` tracks per-topic read state but the home-screen "Weiterlesen" surface needs verification — module rendering exists in `HomeView` but resume-position fidelity is untested. |
| Android  | Not started             | Same `ReadingProgress` shape; DataStore-backed.                                                |

---

##### FR-HOME-005 — "Übernommene Aufgaben"

**User goal.** As a member who has claimed volunteer tasks, I want
a reminder on the home screen of what I've signed up for so I don't
forget — and a one-tap path to mark them done.

**Acceptance criteria.**

- A module lists the user's currently-claimed ToDos.
- Each row shows the task title and any deadline.
- Tapping a row opens the task detail.
- The list updates when the user claims, completes, or releases a
  task elsewhere in the app.
- Hidden when the user has no claimed tasks.

**Platforms.**

| Platform | Status      | Notes                                                                  |
|----------|-------------|------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `HomeViewModel` fetches via `TodoRepository`, filters by `currentUser`. |
| Android  | Not started | Same Todo data, same filter.                                          |

### 3.3 Forum (FORUM)

The Forum section is the largest user-facing surface in the app and the
test bed for the user-story / acceptance-criteria / platform-status format
that augments the FR table below. The MoSCoW summary table stays as a
quick lookup; the **Extended specs** subsection below expands each FR
with a user goal, testable acceptance criteria, and per-platform
implementation status — the shape an Android port (or another
contributor) builds against.

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-FORUM-001 | Must | List topics with unread activity first, showing title, author, last-activity timestamp, reply count and view count. |
| FR-FORUM-002 | Must | Tapping a topic opens the post list with threaded replies. |
| FR-FORUM-003 | Must | The user can post a reply (plain markdown, same flavour Discourse accepts). |
| FR-FORUM-004 | Must | The user can like and unlike individual posts, and the state is synced to Discourse (not displayed optimistically only). |
| FR-FORUM-005 | Must | The user can pin Discourse categories (e.g. their Landesverband). Pin state is stored in UserDefaults, device-local only. |
| FR-FORUM-006 | Must | Inline image rendering for posts. Images must render at their natural aspect ratio — never stretched beyond their actual dimensions. |
| FR-FORUM-007 | Must | Reading a topic marks it as read on Discourse so read state is consistent across devices. |
| FR-FORUM-008 | Should | The user can create a new forum topic. |

#### Extended specs — Forum

##### FR-FORUM-001 — List topics, unread first

**User goal.** As a member, I want to see the forum's most recent and
unread topics first so I can quickly catch up on what the party is
discussing.

**Acceptance criteria.**

- Topics with unread activity appear above fully-read topics in the
  list.
- Each row shows: title, author username, last-activity timestamp
  (relative — "vor 2 Stunden"), reply count, view count.
- Initial render shows cached topics within ~200 ms; fresh data
  fetches asynchronously without blocking the UI.
- Pull-to-refresh bypasses the staleness guard and forces a network
  fetch.
- Tapping a row navigates to the topic detail (FR-FORUM-002).

**Platforms.**

| Platform | Status      | Notes                                                    |
|----------|-------------|----------------------------------------------------------|
| iOS      | ✅ Shipped  | `ForumViewModel` + `ForumView`, cache via `DiscourseCacheStore`. |
| Android  | Not started | Same `GET /latest.json` Discourse API; same cache model. |

---

##### FR-FORUM-002 — Open a topic

**User goal.** As a member, I want to tap a topic and read its full
thread with reply context preserved so I can follow the conversation
accurately.

**Acceptance criteria.**

- Tapping a topic in the list opens a dedicated detail screen.
- All posts in the topic load in `post_number` ascending order.
- Reply-to relationships are visible (e.g., post #5 visually indicates
  it's a reply to #4).
- Topics with more than 20 posts paginate via Discourse's
  `post_ids[]=` batched fetch (the API's hard limit per request).
- Pull-to-refresh on the detail re-fetches.

**Platforms.**

| Platform | Status      | Notes                                                                       |
|----------|-------------|-----------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `TopicDetailViewModel` + `TopicDetailView`; uses `ScrollView + LazyVStack` (D-030) instead of `List` to avoid the `UICollectionView` dequeue crash. |
| Android  | Not started | Same `GET /t/{id}.json` Discourse API. Compose's `LazyColumn` is the equivalent of `LazyVStack`. |

---

##### FR-FORUM-003 — Reply to a post

**User goal.** As a member, I want to reply to a forum post so I can
participate in the discussion.

**Acceptance criteria.**

- A reply button on each post opens a compose sheet.
- Compose accepts plain markdown (Discourse's own flavour).
- Submit sends `POST /posts.json` with `topic_id` and optional
  `reply_to_post_number`.
- On success: the new post appears in the topic without a manual
  refresh; the compose sheet closes.
- On failure: the compose sheet stays open with typing preserved; an
  error message surfaces.
- The user cannot submit an empty reply.

**Platforms.**

| Platform | Status      | Notes |
|----------|-------------|-------|
| iOS      | ✅ Shipped  | Compose flow in `TopicDetailView`, with the `ReplyComposerView` sheet. |
| Android  | Not started | Same `POST /posts.json` API. |

---

##### FR-FORUM-004 — Like / unlike a post

**User goal.** As a member, I want to like a forum post to show
appreciation without writing a reply, and unlike it within Discourse's
permitted window if I tapped by accident.

**Acceptance criteria.**

- Tapping the heart icon records the like server-side via
  `POST /post_actions`.
- The like is visible from any other Discourse client (web, official
  mobile app) within ~1 minute.
- Unlike works within Discourse's `post_undo_action_window_mins`
  (default 10 min); after the window, Discourse server-side locks the
  like and the unlike action is no longer available.
- Failures surface to the user — the heart state never lies (no silent
  optimistic-only display).

**Platforms.**

| Platform | Status      | Notes                                                            |
|----------|-------------|------------------------------------------------------------------|
| iOS      | ✅ Shipped  | Verified end-to-end 2026-05-20. Root cause history in [ADR-0014](./adr/0014-like-strategy-chain.md) — the `HTTPRequest.post` factory was overriding the caller's `Content-Type` to `application/json` on a form-encoded body. |
| Android  | Not started | Same `POST /post_actions` form-encoded API. **OkHttp has the same pitfall** — set Content-Type explicitly on the `RequestBody` and don't let any wrapper override it. |

---

##### FR-FORUM-005 — Pin Discourse categories

**User goal.** As a member, I want to pin the Discourse categories I
follow most often (e.g., my Landesverband) so they're easier to find
at a glance in the forum tab.

**Acceptance criteria.**

- A pin gesture or button on a category persists the pin locally.
- Pinned categories appear at the top of the forum tab listing.
- Pin state is device-local (UserDefaults), never synced to the
  server — matches the app's no-tracking baseline.
- Unpinning is symmetric.
- Pinned-category ordering reflects pin chronology (newest first) OR
  alphabetical — decision deferred to UX implementation.

**Platforms.**

| Platform | Status      | Notes                                                     |
|----------|-------------|-----------------------------------------------------------|
| iOS      | Not started | No `ForumPinStore` exists yet; UI affordance also missing. |
| Android  | Not started | Use Jetpack DataStore for the local pin set.              |

---

##### FR-FORUM-006 — Inline image rendering in posts

**User goal.** As a member, I want to see images inline in forum posts
so I can read the full content without leaving the app.

**Acceptance criteria.**

- Images embedded in a post's HTML body are extracted and rendered
  inline at their natural aspect ratio.
- Images never stretch beyond their natural dimensions (no upscaling).
- Image load failures show a placeholder, not a broken state.
- Tapping an image opens it full-screen (zoom-and-pan) — Should, not
  Must for v1.

**Platforms.**

| Platform | Status      | Notes                                                                              |
|----------|-------------|------------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `HTMLContentParser.extractImageURLs` + SwiftUI `AsyncImage` in `TopicDetailView`. |
| Android  | Not started | Same image-URL extraction; Coil for async loading.                                  |

---

##### FR-FORUM-007 — Mark topics as read

**User goal.** As a member, I want my "read" state to follow me across
devices — if I read a topic on the iOS app, I shouldn't see it as
unread when I open Discourse on the web.

**Acceptance criteria.**

- After the user finishes reading a topic (closes the detail view or
  scrolls past the last post), the app sends `POST /topics/timings`
  with the highest seen `post_number`.
- The server confirms the timing record (no client-side staleness).
- Failure to mark-as-read does not block any other functionality; it
  retries silently on the next topic visit.

**Platforms.**

| Platform | Status      | Notes                                                            |
|----------|-------------|------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `RealDiscourseRepository.markTopicAsRead` fires on `onDisappear` of `TopicDetailView`. |
| Android  | Not started | Same `POST /topics/timings` API.                                 |

---

##### FR-FORUM-008 — Create a new forum topic

**User goal.** As a member, I want to start a new forum topic from
the app so I can raise discussions without switching to the web
browser.

**Acceptance criteria.**

- A "New topic" button is visible from the forum list.
- The compose sheet collects: category (required), title (required),
  markdown body (required).
- Submit sends `POST /posts.json` with `archetype=regular` and the
  selected `category` ID.
- On success: the new topic appears at the top of the forum list (by
  virtue of `last_activity_at`); the user navigates to it.
- The user cannot submit with an empty title or body.

**Platforms.**

| Platform | Status      | Notes                                                  |
|----------|-------------|--------------------------------------------------------|
| iOS      | Not started | No `NewTopicView` exists yet.                          |
| Android  | Not started | Same `POST /posts.json` API; same compose-form shape. |

### 3.4 Wissen — knowledge (KNOW)

Content is sourced from the [PIRATEN-Kanon](https://github.com/sebulino/PIRATEN-Kanon) repository.

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-KNOW-001 | Must | Fetch Kanon content from GitHub and render each entry as a screen with readable typography, reading-time estimate and "Einsteiger / Fortgeschritten" tagging. |
| FR-KNOW-002 | Must | Kanon content is cached locally so the user can read it offline and start-up does not block on network. On startup the app fetches the latest remote commit SHA; if it differs from the stored SHA, content is re-downloaded (see [ADR-0011](./adr/0011-kanon-sha-tracking.md)). |
| FR-KNOW-003 | Must | Each Kanon entry may define a short **quiz** (multiple-choice). The app renders the quiz, checks answers locally, and tracks the user's progress via `ReadingProgressStore` (UserDefaults, device-local, keyed per PiratenSSO `sub`). |
| FR-KNOW-004 | Should | A topic search bar filters entries by title and tags. |
| FR-KNOW-005 | Should | Categories (Wahlen und Parlamente, Kommunalpolitik, Partei-intern, Organisation und Ämter …) are shown as a grid. |
| FR-KNOW-006 | Could | Quiz results are optionally reported back to the member's profile ("achievements"). Requires backend support that does not yet exist. |

#### Extended specs — Wissen (knowledge)

##### FR-KNOW-001 — Render Kanon entries

**User goal.** As a member (especially a new one), I want to read
introductory and reference material about the party in a comfortable,
phone-friendly format so I can learn while I have a few minutes.

**Acceptance criteria.**

- Each Kanon entry renders as a dedicated screen with title, body,
  estimated reading time, and level badge ("Einsteiger" /
  "Fortgeschritten").
- Body content uses readable typography (line spacing, font sizing
  appropriate for prose).
- The reading-time estimate is computed from word count (≈200 wpm).
- Level badge color is consistent across the section.

**Platforms.**

| Platform | Status      | Notes                                                                  |
|----------|-------------|------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `KnowledgeTopicDetailView`, `KnowledgeTopicDetailViewModel`, custom Markdown rendering. |
| Android  | Not started | Same content shape; Compose Markdown library exists.                  |

---

##### FR-KNOW-002 — Offline cache + SHA-tracked re-download

**User goal.** As a member with spotty mobile signal, I want Kanon
content available offline — and I want updates to land automatically
when the maintainers push new content, without me having to think
about refreshing.

**Acceptance criteria.**

- All Kanon entries are cached to local storage after first fetch.
- App startup does not block on network — cached content renders
  immediately.
- On startup, the app fetches the latest remote commit SHA from the
  Kanon GitHub repository.
- If the remote SHA differs from the stored SHA, content is
  re-downloaded in the background and the cache is replaced
  atomically (see [ADR-0011](./adr/0011-kanon-sha-tracking.md)).
- The stored SHA is persisted to UserDefaults for the next launch.
- Cache failure does not block reading existing content.

**Platforms.**

| Platform | Status      | Notes                                                            |
|----------|-------------|------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `RealKnowledgeRepository` + `KnowledgeCacheManager` + ETag-based fetch via `GitHubAPIClient`. |
| Android  | Not started | Same GitHub Contents API; Room or DataStore for cache.            |

---

##### FR-KNOW-003 — Per-entry multiple-choice quiz

**User goal.** As a new member working through introductory content,
I want short quizzes at the end of entries to test whether I've
actually understood the material.

**Acceptance criteria.**

- Each Kanon entry can define a quiz in its YAML frontmatter (zero
  or more multiple-choice questions).
- The quiz renders below the entry body.
- Each question has one correct answer; the UI marks correct/incorrect
  after submission.
- Per-quiz progress is tracked in `ReadingProgressStore` (UserDefaults,
  device-local).
- Progress is keyed per PiratenSSO `sub` so multi-user devices don't
  cross-contaminate.

**Platforms.**

| Platform | Status      | Notes                                                                |
|----------|-------------|----------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `QuizCard` view + `ReadingProgressStore` keyed by `sub`.            |
| Android  | Not started | Same YAML frontmatter; same DataStore-keyed-per-`sub` pattern.       |

---

##### FR-KNOW-004 — Topic search

**User goal.** As a member looking for a specific topic ("Was ist die
Kreisparteitags-Geschäftsordnung?"), I want to find it in seconds
rather than browsing the category tree.

**Acceptance criteria.**

- A search bar at the top of the Wissen tab filters by title and
  tags.
- Filtering is in-memory against the local cache (no network call
  per keystroke).
- Empty search shows the full grid.
- "Keine Treffer" empty state when filter excludes everything.

**Platforms.**

| Platform | Status      | Notes                                                       |
|----------|-------------|-------------------------------------------------------------|
| iOS      | Not started | Search bar UI exists in some forms; verify implementation.  |
| Android  | Not started | Same approach; Compose `OutlinedTextField` + filter logic.  |

---

##### FR-KNOW-005 — Category grid

**User goal.** As a member browsing without a specific search in
mind, I want to see the available categories at a glance and pick
something that looks relevant.

**Acceptance criteria.**

- The Wissen tab top-level shows a grid of categories with name +
  icon.
- Categories come from `kanon.json` (the index file in the Kanon repo).
- Tapping a category opens its entry list.
- Grid layout adapts to phone width (2 columns portrait, 3 landscape).

**Platforms.**

| Platform | Status      | Notes                                       |
|----------|-------------|---------------------------------------------|
| iOS      | ✅ Shipped  | `KnowledgeView` `LazyVGrid`.                 |
| Android  | Not started | Compose `LazyVerticalGrid`.                 |

---

##### FR-KNOW-006 — Quiz achievements (deferred)

**User goal.** As a member who's completed several quizzes, I want
some kind of recognition or progress display in my profile so I can
see how much I've learned.

**Acceptance criteria (target post-v1).**

- Quiz completions accumulate as an "achievement" count.
- Visible from the Profile screen.
- Requires backend support to persist across devices — currently no
  such backend exists.

**Platforms.**

| Platform | Status   | Notes                                                                          |
|----------|----------|--------------------------------------------------------------------------------|
| iOS      | Deferred | Post-v1. Requires `meine-piraten.de` API extension.                            |
| Android  | Deferred | Post-v1. Same.                                                                 |

### 3.5 Termine — events (EVT)

Source: Agitatorrr iCal feed.

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-EVT-001 | Must | Fetch upcoming events from the Agitatorrr iCal feed and list them chronologically with date, time, title, location / URL and a type badge (Treffen, Aktion, …). |
| FR-EVT-002 | Must | Tapping an event opens a detail view with the full description and any Jitsi / Mumble / address link as a tappable action. |
| FR-EVT-003 | Must | Users can add an event to the iOS Calendar via EventKit with one tap. |
| FR-EVT-004 | Could | Filter by Landesverband / region. (Deferred to post-v1.) |
| FR-EVT-005 | Could | Pull-to-refresh and automatic background refresh with sensible TTL. |

#### Extended specs — Termine (events)

##### FR-EVT-001 — List upcoming events chronologically

**User goal.** As a member, I want to see what's happening in the
party — meetings, actions, gatherings — in a single chronological
feed without scrolling through Discourse threads or external
calendar apps.

**Acceptance criteria.**

- The Termine tab lists events sorted by start date ascending.
- Each row shows: date + time, title, location or URL preview, and a
  type badge (Treffen, Aktion, …).
- Past events are hidden by default.
- Events come from the Agitatorrr iCal feed.

**Platforms.**

| Platform | Status      | Notes                                                                                       |
|----------|-------------|---------------------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `CalendarViewModel` + `CalendarView`; custom `ICalParser` (no third-party library, per ADR-0013). |
| Android  | Not started | Same iCal feed; ical4j or hand-rolled parser.                                                |

---

##### FR-EVT-002 — Event detail view

**User goal.** As a member who's interested in an event, I want to
see its full description and tap directly into the Jitsi / Mumble
link without copy-pasting.

**Acceptance criteria.**

- Tapping an event opens a detail view.
- Detail shows full description, start/end times, location.
- Any URL in the description (Jitsi room, Mumble server, web link,
  address) is rendered as a tappable action.
- Tapping a video-conference URL opens the corresponding app if
  installed (Jitsi Meet, Mumble) or falls back to Safari.

**Platforms.**

| Platform | Status      | Notes                                                                               |
|----------|-------------|-------------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `CalendarEvent` detail rendering. URL detection via `NSDataDetector`.              |
| Android  | Not started | Same data shape; Android Intent system for app handoff.                            |

---

##### FR-EVT-003 — Add to iOS Calendar

**User goal.** As a member who wants to attend an event, I want
one-tap "add to my calendar" so the event shows up alongside my
other commitments without me re-entering it.

**Acceptance criteria.**

- Detail view has an "Add to Calendar" action.
- Tapping triggers the EventKit permission prompt if not granted.
- On grant, a new `EKEvent` is created in the user's default calendar
  with title, start/end, location, and description.
- Confirmation: "Termin wurde dem Kalender hinzugefügt."
- Re-adding the same event creates a duplicate (no de-duplication —
  iOS calendar surface decides).
- Adding without permission shows an actionable "open Settings"
  prompt.

**Platforms.**

| Platform | Status      | Notes                                                                |
|----------|-------------|----------------------------------------------------------------------|
| iOS      | ✅ Shipped  | EventKit integration via `CalendarExporter`. `NSCalendarsUsageDescription` in Info.plist. |
| Android  | Not started | `Intent(ACTION_INSERT)` with `CalendarContract.Events` extras.        |

---

##### FR-EVT-004 — Region filter (deferred)

**User goal.** As a member of a specific Landesverband, I want to
see only events relevant to my region rather than the national feed.

**Acceptance criteria (target post-v1).**

- A filter chip set at the top of the Termine tab lists available
  regions.
- Selecting a region filters events whose location or tags match.
- "Alle" option shows all events.
- Filter selection persists across sessions.

**Platforms.**

| Platform | Status   | Notes                                                       |
|----------|----------|-------------------------------------------------------------|
| iOS      | Deferred | Post-v1. Depends on Agitatorrr feed surfacing region tags. |
| Android  | Deferred | Post-v1. Same.                                              |

---

##### FR-EVT-005 — Pull-to-refresh + background TTL

**User goal.** As a member who checks events regularly, I want the
list to stay reasonably fresh without me having to manually refresh,
but I also want a way to force-refresh when I know something just
changed.

**Acceptance criteria.**

- Pull-to-refresh on the Termine tab triggers an immediate iCal
  fetch.
- Background refresh runs as part of the `BGAppRefreshTask` polling
  cycle (FR-NOTIF-003 covers the cadence).
- Stale-list TTL is documented and consistent with other content
  surfaces (e.g., 5 min foreground, 30 min background).

**Platforms.**

| Platform | Status      | Notes                                                          |
|----------|-------------|----------------------------------------------------------------|
| iOS      | ✅ Shipped  | `BackgroundRefreshCoordinator` includes Events as one of six sources. |
| Android  | Not started | `WorkManager`-based equivalent.                                  |

### 3.6 ToDos — volunteer tasks (TODO)

Source: `meine-piraten.de` (see [API documentation](https://meine-piraten.de/api)).
Tasks follow a status state machine: `open → claimed → completed → done`.

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-TODO-001 | Must | List open tasks with title, category badge ("Veranstaltungsorga", "Wahlkampf", …), region (entity), estimated duration and deadline. |
| FR-TODO-002 | Must | The user can **claim** (`übernehmen`) a task (`open → claimed`); it then appears under "Übernommene Aufgaben" on the Kajüte. |
| FR-TODO-003 | Must | The user can mark a claimed task as completed (`claimed → completed`). |
| FR-TODO-004 | Should | Tasks can be filtered by region and category. |
| FR-TODO-005 | Must | A user can release a claimed task back to the pool (`claimed → open`) if they can no longer do it. |
| FR-TODO-006 | Must | ToDos are polled in the background every 30 minutes via BGAppRefreshTask, plus refreshed when the user opens the tab. New or updated tasks update the tab badge. |
| FR-TODO-007 | Should | Users can comment on tasks. |

#### Extended specs — ToDos (volunteer tasks)

##### FR-TODO-001 — List open tasks

**User goal.** As a member who wants to help out, I want to see what
the party needs done — by category and region — so I can pick
something that fits my skills, time, and location.

**Acceptance criteria.**

- The Aufgaben tab lists open ToDos (status `open`, not yet claimed).
- Each row shows title, category badge ("Veranstaltungsorga",
  "Wahlkampf", etc.), region (entity), estimated duration, and
  deadline.
- Tasks are fetched from `meine-piraten.de/tasks.json`.
- Sorted by urgency / deadline ascending.
- Pull-to-refresh fetches fresh data.

**Platforms.**

| Platform | Status      | Notes                                                                          |
|----------|-------------|--------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `TodosViewModel` + `TodosView`; data via `RealTodoRepository`.                |
| Android  | Not started | Same `meine-piraten.de/tasks.json` API.                                       |

---

##### FR-TODO-002 — Claim a task

**User goal.** As a member who's decided to take on a specific task,
I want to claim it so other members see it's covered and don't
duplicate the work.

**Acceptance criteria.**

- A "Übernehmen" button on each open task.
- Tapping transitions the task `open → claimed` server-side via
  `PATCH /tasks/:id.json` with `state=claimed`.
- The task moves out of the open list and appears under
  "Übernommene Aufgaben" on the Kajüte (FR-HOME-005).
- The Aufgaben tab updates its badge to reflect the change.
- Failure (network, conflict if someone else claimed first) shows a
  clear message.

**Platforms.**

| Platform | Status      | Notes                                                            |
|----------|-------------|------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `TodoDetailViewModel.claim` + `RealTodoRepository.claimTodo`.   |
| Android  | Not started | Same API endpoint.                                                |

---

##### FR-TODO-003 — Mark as completed

**User goal.** As a member who's finished a claimed task, I want to
mark it done so the coordinators know it's no longer in flight.

**Acceptance criteria.**

- A "Erledigt" button on claimed tasks.
- Transitions `claimed → completed` server-side.
- The task disappears from "Übernommene Aufgaben" on Kajüte.
- Optional confirmation dialog ("Wirklich als erledigt markieren?").

**Platforms.**

| Platform | Status      | Notes                                                          |
|----------|-------------|----------------------------------------------------------------|
| iOS      | ✅ Shipped  | `TodoDetailViewModel.complete`.                                |
| Android  | Not started | Same API endpoint.                                              |

---

##### FR-TODO-004 — Filter by region and category

**User goal.** As a member with a specific area of interest or
geographic focus, I want to filter the task list to only show
relevant items.

**Acceptance criteria.**

- Filter chips at the top of the Aufgaben tab for region (entity)
  and category.
- Multiple chips can be active simultaneously (intersection).
- "Alle" / "Reset" option to clear filters.
- Filter state is session-scoped (resets on app restart) — not
  persisted, by design.

**Platforms.**

| Platform | Status      | Notes                                            |
|----------|-------------|--------------------------------------------------|
| iOS      | Partial     | Filter UI exists; verify region+category combo.  |
| Android  | Not started | Same approach.                                   |

---

##### FR-TODO-005 — Release a claimed task

**User goal.** As a member who claimed a task but can no longer do
it (priority changed, ran out of time), I want to release it back to
the pool so someone else can pick it up — without having to
abandon it silently.

**Acceptance criteria.**

- A "Freigeben" button on claimed tasks.
- Transitions `claimed → open` server-side.
- The task disappears from "Übernommene Aufgaben" and reappears in
  the open-task list.
- Failure shows a clear message.

**Platforms.**

| Platform | Status      | Notes                                                          |
|----------|-------------|----------------------------------------------------------------|
| iOS      | ✅ Shipped  | `RealTodoRepository.unclaimTodo`.                              |
| Android  | Not started | Same API.                                                      |

---

##### FR-TODO-006 — Background polling + badge

**User goal.** As a member who's already claimed tasks, I want the
app to keep me aware of new tasks in my region without me having to
remember to check the tab.

**Acceptance criteria.**

- ToDos are polled every ~30 min as part of the
  `BGAppRefreshTask` cycle (FR-NOTIF-003).
- New tasks since the last seen one update the Aufgaben tab badge.
- Foreground refresh on tab visit also runs (subject to
  `StalenessGuard` — see ADR-0010 for the cache+guard pattern).
- If the user has enabled the Aufgaben notification toggle
  (FR-PROF-002), a local notification fires for new tasks
  (FR-NOTIF-004).

**Platforms.**

| Platform | Status      | Notes                                                                |
|----------|-------------|----------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `BackgroundRefreshCoordinator` includes ToDos as one of six sources. |
| Android  | Not started | `WorkManager`-based equivalent.                                       |

---

##### FR-TODO-007 — Comments on tasks

**User goal.** As a member coordinating with others on a task, I
want to leave or read notes about the task (logistics, questions,
status updates) without spinning up a separate Discourse thread.

**Acceptance criteria.**

- Task detail shows a comments section.
- The user can read existing comments (with author + timestamp).
- The user can post a new comment.
- Comments are sourced from `meine-piraten.de/tasks/:id/comments.json`.

**Platforms.**

| Platform | Status      | Notes                                                                      |
|----------|-------------|----------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `TodoComment` model + comments section in `TodoDetailView`.               |
| Android  | Not started | Same comment API.                                                          |

### 3.7 Nachrichten — private messages (MSG)

Messages are **Discourse PMs**, not a separate system.

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-MSG-001 | Must | List message threads with participant avatars, preview of last message, and unread state. |
| FR-MSG-002 | Must | Open a thread to read all messages chronologically. |
| FR-MSG-003 | Must | Reply to an existing thread. |
| FR-MSG-004 | Must | Start a new thread with one or more recipients (user search via Discourse). |
| FR-MSG-005 | Should | Reading a thread marks it as read on Discourse (symmetrical to forum read state). |
| FR-MSG-006 | Should | On tab-switch, only the inbox is fetched. Sent messages are fetched on explicit pull-to-refresh (optimisation; sent messages change rarely). |

#### Extended specs — Nachrichten (private messages)

##### FR-MSG-001 — List message threads

**User goal.** As a member, I want to see my private messages at a
glance with enough context (who, what about, when) to decide which
to open without tapping into each one.

**Acceptance criteria.**

- The Messages sheet lists threads sorted by last-activity descending.
- Each row shows participant avatar(s), thread title, preview of
  last message body, and an unread indicator.
- Inbox + sent threads are merged and deduplicated by ID.
- Initial render shows cached threads; fresh data loads in the
  background.

**Platforms.**

| Platform | Status      | Notes                                                            |
|----------|-------------|------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `MessagesViewModel` + `MessagesView`; cache via `DiscourseCacheStore`. |
| Android  | Not started | Same Discourse private-messages API.                              |

---

##### FR-MSG-002 — Open a thread

**User goal.** As a member, I want to tap a message thread and read
the conversation chronologically, like a chat.

**Acceptance criteria.**

- Tapping a thread opens a detail view.
- Messages render as chat bubbles (the user's own messages
  right-aligned, others left-aligned) per [D-035](./decisions-log.md).
- All messages in the thread load in `post_number` ascending order.
- Body content supports markdown.
- Scrolls to the most recent message on open.

**Platforms.**

| Platform | Status      | Notes                                                                          |
|----------|-------------|--------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `MessageThreadDetailViewModel` + `MessageThreadDetailView`; uses chat-bubble layout. |
| Android  | Not started | Same Discourse `/t/{id}.json` API.                                              |

---

##### FR-MSG-003 — Reply to a thread

**User goal.** As a member in a conversation, I want to reply
without leaving the thread view.

**Acceptance criteria.**

- A compose field is anchored to the bottom of the detail view.
- Submit sends `POST /posts.json` with `topic_id` set to the thread.
- On success, the new message appears in the thread.
- On failure, the compose state is preserved.

**Platforms.**

| Platform | Status      | Notes                                                                |
|----------|-------------|----------------------------------------------------------------------|
| iOS      | ✅ Shipped  | Inline composer in `MessageThreadDetailView`.                       |
| Android  | Not started | Same API.                                                            |

---

##### FR-MSG-004 — Start a new thread

**User goal.** As a member, I want to reach out to a specific other
member directly without finding them in a public forum thread first.

**Acceptance criteria.**

- A "Neue Nachricht" action is available from the Messages list.
- The compose flow has three steps: recipient picker (user search),
  subject, body.
- User search hits `GET /u/search/users.json?term=...` with a
  minimum 2-character query, debounced.
- Multiple recipients are supported.
- Submit sends `POST /posts.json` with `archetype=private_message`.
- On success, navigates to the new thread.

**Platforms.**

| Platform | Status      | Notes                                                                                  |
|----------|-------------|----------------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `RecipientPickerViewModel` + `ComposeMessageViewModel`; auto-saved draft via `MessageDraftStore`. |
| Android  | Not started | Same Discourse API; user-search debouncing pattern same.                              |

---

##### FR-MSG-005 — Mark thread as read

**User goal.** As a member who reads a message on this device, I
want the "read" state to be visible on the Discourse web UI too, so
I don't have to mentally track what I've already read.

**Acceptance criteria.**

- After scrolling to the last message of a thread (or closing the
  detail view), the app sends `POST /topics/timings`.
- Server-side read state is updated.
- The inbox row's unread indicator clears on next refresh.
- Failure to mark-as-read does not block the user — retries on next
  thread visit.

**Platforms.**

| Platform | Status      | Notes                                                              |
|----------|-------------|--------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `RealDiscourseRepository.markTopicAsRead` on detail-view `onDisappear`. |
| Android  | Not started | Same Discourse `/topics/timings` API.                              |

---

##### FR-MSG-006 — Tab-switch fetches inbox only

**User goal.** As a member who often quickly checks Messages and
moves on, I want the tab to load fast — not block on fetching a
sent-messages list I rarely look at.

**Acceptance criteria.**

- Tab-switch triggers `fetchMessageThreads(for: user, includeSent: false)`.
- Pull-to-refresh on the inbox triggers
  `fetchMessageThreads(for: user, includeSent: true)`.
- Sent threads, once fetched, are merged into the cache and remain
  visible across tab switches until invalidated.

**Platforms.**

| Platform | Status      | Notes                                                                                |
|----------|-------------|--------------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `MessagesViewModel.loadMessages(includeSent: false)` on tab-switch; `true` on refresh. |
| Android  | Not started | Same two-tier fetch pattern.                                                          |

### 3.8 News (NEWS)

Source: `https://meine-piraten.de/api/news.json` (public endpoint).

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-NEWS-001 | Must | Fetch items from the news endpoint and render each as a card with title, source URL and snippet. |
| FR-NEWS-002 | Must | Tapping a card opens the source URL in `SFSafariViewController` (not a `WKWebView`). |
| FR-NEWS-003 | Should | News items are de-duplicated by URL across refreshes. |
| FR-NEWS-004 | Could | Mark-as-read: v1 uses a "last seen" model (the most recent item the user viewed mutes the tab badge), not per-item read state. |

#### Extended specs — News

##### FR-NEWS-001 — Fetch and render news cards

**User goal.** As a member, I want a single place where I can see
news from across the party's channels in a skimmable card format.

**Acceptance criteria.**

- News items are fetched from `meine-piraten.de/api/news`.
- Each item renders as a card with title, source URL, and a snippet
  of body text.
- The leading `<username> [datetime]` prefix line that the news API
  embeds in body text is stripped from display (#67 fix; see
  `NewsItem.displayText`).
- Cards are sorted by `posted_at` descending.
- The card list refreshes on pull-to-refresh.

**Platforms.**

| Platform | Status      | Notes                                                            |
|----------|-------------|------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `NewsViewModel` + `NewsCardView` + `NewsItem.displayText`.       |
| Android  | Not started | Same API; Compose card UI.                                       |

---

##### FR-NEWS-002 — Tap a card → SFSafariViewController

**User goal.** As a member reading a news snippet who wants the full
story, I want to open the source URL in an in-app browser that still
feels native (back button, share sheet) — not as a clunky embedded
web view.

**Acceptance criteria.**

- Tapping a news card opens its source URL.
- The browser presentation is `SFSafariViewController` (not
  `WKWebView`).
- The user can return to the app with a single tap.
- No URL is opened in the external Safari app (would lose context).

**Platforms.**

| Platform | Status      | Notes                                                                          |
|----------|-------------|--------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `SFSafariViewController` integration from news card tap.                       |
| Android  | Not started | Equivalent: Chrome Custom Tabs (`androidx.browser.customtabs`).               |

---

##### FR-NEWS-003 — De-duplicate by URL

**User goal.** As a member who refreshes the news feed periodically,
I don't want to see the same news item repeated as the underlying
endpoint may return overlapping windows.

**Acceptance criteria.**

- News items with the same `messageId` are de-duplicated client-side.
- The most recent occurrence is kept; older duplicates are dropped.
- De-duplication is applied at the cache merge step, not at fetch
  time (so a fresh fetch can correct stale records).

**Platforms.**

| Platform | Status      | Notes                                                            |
|----------|-------------|------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `NewsCacheStore.merge` deduplicates by `messageId`.              |
| Android  | Not started | Same dedup pattern at the cache layer.                          |

---

##### FR-NEWS-004 — "Last seen" mute model

**User goal.** As a member, when I open the News tab I want the
"there's something new" indicator to clear — but I don't need
per-item read state tracking; I just want to know if anything new
has arrived since I last looked.

**Acceptance criteria.**

- The News tab tracks the highest `messageId` the user has seen.
- When the user opens the tab, the highest seen ID is updated.
- The tab badge is hidden when all current items have `messageId
  <= lastSeenMessageId`.
- The badge reappears when fresh content arrives with higher IDs.

**Platforms.**

| Platform | Status      | Notes                                                            |
|----------|-------------|------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `NewsViewModel.lastSeenMessageId` in UserDefaults.               |
| Android  | Not started | Same single-value DataStore entry.                                |

### 3.9 Profile (PROF)

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-PROF-001 | Must | Show the user's name, handle, avatar, e-mail, join date and activity stats (posts, likes given, likes received). |
| FR-PROF-002 | Must | Offer in-app notification toggles for all six categories: Forum, Messages, News, ToDos, Knowledge updates, and Events/Calendar. Each toggle determines whether new activity in that category triggers a local push notification (banner + sound). Polling always runs; the toggle only gates display. |
| FR-PROF-003 | Should | Offer a logout action. |
| FR-PROF-005 | Must | Tapping any member's name or avatar (in forum posts, messages, or "Letzte Kontakte") opens their profile: a Discourse user card showing avatar, username, join date and post count. |
| FR-PROF-006 | Should | The user can compose and send feedback to the app maintainer via an in-app form. |
| FR-PROF-007 | Should | The user can request admin privileges on `meine-piraten.de` via an in-app form (`POST /admin_requests.json`). |

*Note: FR-PROF-004 (data export link) was removed — see Q-048 in `decisions-log.md`.*

#### Extended specs — Profile

##### FR-PROF-001 — Show user profile

**User goal.** As a member, I want to see my identity and activity
in the Discourse forum at a glance — name, handle, avatar, when I
joined, and my participation stats.

**Acceptance criteria.**

- Profile sheet shows: full name (from PiratenSSO), handle
  (Discourse `username`), avatar (Discourse), e-mail (PiratenSSO),
  join date (Discourse `created_at`), and activity stats (posts,
  likes given, likes received).
- If Discourse profile data is unavailable, a non-blocking note
  appears; the SSO data still renders.

**Platforms.**

| Platform | Status      | Notes                                                                  |
|----------|-------------|------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `ProfileViewModel` merges PiratenSSO `User` with Discourse `UserProfile`. |
| Android  | Not started | Same two-source merge.                                                  |

---

##### FR-PROF-002 — Six notification toggles

**User goal.** As a member, I want fine-grained control over which
kinds of new activity trigger a notification on my phone, so I can
opt into the categories I care about without being spammed.

**Acceptance criteria.**

- Six toggles in Profile: Forum, Nachrichten, News, ToDos, Wissen,
  Termine.
- Each toggle's state is persisted to UserDefaults.
- All toggles default off (opt-in for privacy — no surprise
  notifications).
- Enabling any toggle triggers the `UNUserNotificationCenter`
  permission prompt if not yet granted.
- Toggle state only gates **display** (whether a banner fires) —
  polling still runs regardless so tab badges stay current (see
  [ADR-0015](./adr/0015-background-notification-coordinator.md)).
- A "system permission denied" indicator with a link to Settings
  when the user has system-level permission revoked.

**Platforms.**

| Platform | Status      | Notes                                                                  |
|----------|-------------|------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `NotificationSettingsManager` with six properties.                     |
| Android  | Not started | Same six-toggle pattern; runtime permission via `POST_NOTIFICATIONS`.   |

---

##### FR-PROF-003 — Logout

Same shape as FR-AUTH-005. The Profile entry IS the logout entry.

**Platforms.**

| Platform | Status      | Notes                                                  |
|----------|-------------|--------------------------------------------------------|
| iOS      | ✅ Shipped  | Same `AuthStateManager.logout()`.                     |
| Android  | Not started | Same.                                                  |

---

##### FR-PROF-005 — Member profile cards

(FR-PROF-004 was retired per Q-048; numbering is stable, no
renumber.)

**User goal.** As a member reading a post or message from someone I
don't know, I want to tap their name to see who they are —
avatar, join date, and basic activity.

**Acceptance criteria.**

- Usernames and avatars in posts, messages, and Kajüte's "Letzte
  Kontakte" are tappable.
- Tapping opens a Discourse user-card sheet showing avatar,
  username, full name (if present), join date, post count.
- The sheet has a "Nachricht senden" action that pre-fills the
  compose flow with that user as recipient.

**Platforms.**

| Platform | Status      | Notes                                                              |
|----------|-------------|--------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `UserProfileView` + `UserProfileViewModel`.                       |
| Android  | Not started | Same Discourse `/u/{username}.json` API.                          |

---

##### FR-PROF-006 — Feedback to the maintainer

**User goal.** As a member who wants to suggest something or report
a problem, I want a frictionless way to send feedback directly to
the app maintainer without leaving the app.

**Acceptance criteria.**

- A "Feedback senden" entry in Profile.
- Tapping opens a compose form with a single text field.
- Submitting sends a Discourse private message to the maintainer
  (@sebulino).
- Confirmation message on success; clear error on failure.

**Platforms.**

| Platform | Status      | Notes                                                  |
|----------|-------------|--------------------------------------------------------|
| iOS      | ✅ Shipped  | `FeedbackViewModel` + `FeedbackComposeView`.          |
| Android  | Not started | Same Discourse PM API.                                |

---

##### FR-PROF-007 — Request admin access

**User goal.** As a member who needs admin privileges on
meine-piraten.de (for example, to administer a region's task feed),
I want to request access from inside the app rather than via email.

**Acceptance criteria.**

- Profile shows an "Admin-Zugang beantragen" entry — visible only
  if the user is not already admin.
- Tapping opens a form with a "Begründung" text field.
- Submitting sends `POST /admin_requests.json` with the reason.
- Confirmation message on success.
- After successful request, the entry is hidden until status
  changes.

**Platforms.**

| Platform | Status      | Notes                                                  |
|----------|-------------|--------------------------------------------------------|
| iOS      | ✅ Shipped  | `AdminRequestViewModel` + `AdminRequestView`.         |
| Android  | Not started | Same `meine-piraten.de` API.                          |

### 3.10 Notifications (NOTIF)

See [ADR-0006](./adr/0006-notifications-v1-polling.md).

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-NOTIF-001 | Must | In the foreground, a polling worker fetches notification data on a sensible interval (default 60 s, backoff on error) and updates in-app badges. |
| FR-NOTIF-002 | Must | The Kajüte, Forum, Nachrichten and ToDos tabs reflect unread counts as returned by Discourse / meine-piraten. |
| FR-NOTIF-003 | Must | A BGAppRefreshTask (requested cadence 30 min) polls all six volatile sources (Forum, Messages, News, ToDos, Knowledge, Events). Each source is polled independently so a failure in one does not block the others. |
| FR-NOTIF-004 | Must | When the background task finds new activity in a category for which the user has enabled notifications (see FR-PROF-002), a local iOS notification (banner + sound) is dispatched. |

#### Extended specs — Notifications

##### FR-NOTIF-001 — Foreground polling

**User goal.** As a member with the app open, I want tab badges to
reflect new content within a reasonable time (a minute or so) without
me having to refresh manually.

**Acceptance criteria.**

- While the app is foregrounded, a polling worker runs on a 60 s
  interval (default).
- On polling failure (network, server error), interval backs off
  exponentially (60s → 120s → 240s, capped at 5 min).
- Badge updates reflect the latest poll's counts.
- Polling pauses when the app enters background (`scenePhase ==
  .background`).
- Polling resumes immediately when the app returns to foreground.

**Platforms.**

| Platform | Status      | Notes                                                                  |
|----------|-------------|------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | Foreground `Timer` in `MainTabView` invoking `DiscourseNotificationPoller`. |
| Android  | Not started | Equivalent: `LifecycleScope` coroutine loop, paused on `ON_STOP`.        |

---

##### FR-NOTIF-002 — Tab badges reflect unread counts

**User goal.** As a member glancing at the tab bar, I want each tab's
badge to accurately reflect what's new there, so I can prioritize.

**Acceptance criteria.**

- Kajüte tab badge: 1 if any other section has new content, 0
  otherwise (functions as a "you have something new" indicator).
- Forum tab badge: 1 if there are new topics since the user's last
  seen `topic.id`, 0 otherwise.
- Nachrichten badge: count of unread message threads.
- ToDos badge: 1 if there are new tasks since the user's last seen
  `todo.id`, 0 otherwise.
- Each badge updates within 60 s of the underlying state changing
  (subject to the poll cycle).

**Platforms.**

| Platform | Status      | Notes                                                                                          |
|----------|-------------|------------------------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | Each `ViewModel` exposes `hasNewContent: Bool`; `MainTabView` binds `.badge()` modifier.       |
| Android  | Not started | Same per-VM "hasNewContent" pattern; Material 3 `NavigationBar` badge.                          |

---

##### FR-NOTIF-003 — Background polling, six sources, independent

**User goal.** As a member with the app closed or backgrounded, I
want the app to still find out about new content from every source
that matters — forum posts, DMs, news, tasks, knowledge updates,
events — without one source's failure preventing the others from
being checked.

**Acceptance criteria.**

- A `BGAppRefreshTask` is requested with `earliestBeginDate = now +
  30 min`. iOS controls actual cadence; the app does not retry on
  its own when iOS withholds wakes.
- On each wake-up, the app polls six sources in parallel via a
  `TaskGroup`: Forum, Messages, ToDos, News, Knowledge, Events.
- Each source's poll has its own `do/catch`; one source's failure
  does NOT abort the siblings.
- Each source has an independent "last seen" marker in UserDefaults
  (prefixed `bg_*_last_seen_*`) so detection state survives app
  restarts.
- Polling happens regardless of which notification toggles are on
  (FR-PROF-002 only gates display).

**Platforms.**

| Platform | Status      | Notes                                                                          |
|----------|-------------|--------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `BackgroundRefreshCoordinator` (see [ADR-0015](./adr/0015-background-notification-coordinator.md)). |
| Android  | Not started | `WorkManager` `PeriodicWorkRequest` with `setRequiredNetworkType(CONNECTED)`. Same six-source coroutine fan-out via `coroutineScope { ... }`. |

---

##### FR-NOTIF-004 — Local notification dispatch from background

**User goal.** As a member who's opted into notifications for a
category, I want my phone to actually buzz / show a banner when
something new arrives in that category — even when the app isn't
foregrounded.

**Acceptance criteria.**

- For each source with new activity since the last background wake,
  the coordinator checks
  `NotificationSettingsManager.<category>Enabled`.
- If enabled, a `UNMutableNotificationContent` is scheduled with a
  fixed German title/body per category (see
  `NotificationCategory` enum).
- Notification bodies are generic — they never contain message
  contents, topic titles, or other PII (see threat model T-007).
- Tapping a notification opens the corresponding tab.
- The Discourse-aggregate badge (home-screen unread count) is
  updated by `DiscourseNotificationPoller` separately, with its own
  persisted `lastKnownTotal`.

**Platforms.**

| Platform | Status      | Notes                                                                                                              |
|----------|-------------|--------------------------------------------------------------------------------------------------------------------|
| iOS      | ✅ Shipped  | `BackgroundRefreshCoordinator` + `LocalNotificationScheduler` (fix for OPEN-12 / #75). Real-device BG test pending organic `BGAppRefreshTask` fire. |
| Android  | Not started | `NotificationManagerCompat.notify()` from inside the `WorkManager` worker. Same per-category gating, same generic-body privacy rule. |

---

## 4. Non-functional requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-001 | Platform | iOS 26.2+, iPhone only. The app is built with **SwiftUI**; UIKit only where SwiftUI has gaps (see [ADR-0001](./adr/0001-native-swiftui-app.md)). |
| NFR-002 | Language | All end-user strings are in German (hardcoded in v1; internationalisation is planned post-v1). All code comments, docs, ADRs, commit messages and PR titles are English. |
| NFR-003 | Performance | Cold start to a usable Kajüte screen within **2 s** with warm caches. Network requests must not block the main thread. |
| NFR-004 | Offline | The app must open and show cached Kanon, last-seen forum topics, last-seen events, taken ToDos, and last-seen news without a network connection. |
| NFR-005 | Resilience | No single failing upstream (Discourse, Agitatorrr, meine-piraten, GitHub, PiratenSSO) may prevent other tabs from loading. Each integration degrades independently. |
| NFR-006 | Security | All network traffic is HTTPS with ATS enforced. Tokens live in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. No analytics or third-party SDKs with user-identifying data. |
| NFR-007 | Privacy | The app collects no telemetry in v1. Crash reporting is evaluated post-v1 with a privacy review. |
| NFR-008 | Accessibility | All interactive elements support VoiceOver labels and Dynamic Type up to XXL. Minimum tap target 44 × 44 pt. |
| NFR-009 | Rate limits | The app must respect Discourse rate limits. A single shared HTTP client enforces per-host concurrency and exponential backoff on 429. |
| NFR-010 | Observability | Client-side structured logging via a central `Logger` facade wrapping `os.Logger`. All log messages that could contain user data, tokens, or PII must pass through `LogRedactor`. No raw `print()` calls in shipped code. |
| NFR-011 | Build | The project builds from a fresh checkout with `xcodebuild` and no manual steps beyond copying `Config/Secrets.sample.xcconfig` to `Config/Secrets.xcconfig` and filling in real values. |
| NFR-012 | Licensing | The app source is open source under **EUPL-1.2**. |
| NFR-013 | Text selection | All body text (forum posts, Kanon entries, news items, messages) must be selectable and copyable by the user. |
| NFR-014 | Contribution infrastructure | The repository must provide GitHub issue templates (bug report, feature request) and a pull request template to guide contributors. These apply to all platform implementations of MeinePIRATEN. |
| NFR-015 | Cache migrations | Each JSON cache store persists a version integer alongside its data. On launch, if the stored version is outdated, the cache is cleared and data re-fetched from the network. |
| NFR-016 | Repository pattern | Every feature is accessed through a `<Feature>Repository` protocol. `Real<Feature>Repository` is used in dev and production; `Fake<Feature>Repository` exists only in test targets. In-flight and empty-cache states are rendered as skeleton / placeholder UI — never as fake data. |
| NFR-017 | Minimal dependencies | New third-party dependencies require explicit justification in an ADR. Lightweight hand-rolled implementations are preferred over pulling in full libraries (see [ADR-0013](./adr/0013-minimal-third-party-dependencies.md)). |

---

## 5. Data handled

| Data | Source of truth | Stored on device? | Notes |
|---|---|---|---|
| Identity (sub, name, email) | PiratenSSO | Keychain (tokens); memory (claims) | Minimum necessary. |
| Discourse User API Key | Discourse | Keychain | Obtained via `/user-api-key/new` handshake. |
| Forum topics, posts, PMs, user profiles | Discourse | UserDefaults (JSON-encoded) | Cache is advisory; Discourse is authoritative. |
| Forum category pins | Device | UserDefaults | Non-sensitive, device-local. |
| Kanon content | GitHub repo | Filesystem (app support dir) | SHA-tracked; re-downloaded when remote SHA changes. |
| Reading progress / quiz state | Device | UserDefaults | Keyed per PiratenSSO `sub`. |
| Events | Agitatorrr | UserDefaults | Refreshed on demand and in background. |
| ToDos | meine-piraten.de | Network-first | Assignments write-through to server. |
| News | meine-piraten.de | UserDefaults | Dedup by URL. |
| Notification preferences | Device | UserDefaults | Non-sensitive. |

No analytics, no crash reporter in v1, no third-party ad SDKs, ever.

---

## 6. Acceptance criteria for v1

The app is ready for a first TestFlight release when:

1. A member can install, log in via PiratenSSO, and land on a populated Kajüte.
2. All tabs (Kajüte, Forum, Wissen, Termine, ToDos) load real data; Profile, Nachrichten, News are reachable.
3. A member can post a reply on Discourse from the app and see it immediately in the Discourse web view.
4. A member can like a forum post and the like is visible on Discourse on another device (OPEN-02 resolved).
5. A member can take on a ToDo and see it on their Kajüte.
6. A member can read a Kanon entry, take its quiz, and see their score.
7. A local iOS notification is delivered when the background task finds new activity in an enabled category (OPEN-12 resolved).
8. The app still opens usefully with the network disabled.
9. At least one external reviewer (not Sebastian) can build the project from scratch using only `docs/` and `Config/Secrets.sample.xcconfig`.
