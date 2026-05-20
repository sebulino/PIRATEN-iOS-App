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

### 3.8 News (NEWS)

Source: `https://meine-piraten.de/api/news.json` (public endpoint).

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-NEWS-001 | Must | Fetch items from the news endpoint and render each as a card with title, source URL and snippet. |
| FR-NEWS-002 | Must | Tapping a card opens the source URL in `SFSafariViewController` (not a `WKWebView`). |
| FR-NEWS-003 | Should | News items are de-duplicated by URL across refreshes. |
| FR-NEWS-004 | Could | Mark-as-read: v1 uses a "last seen" model (the most recent item the user viewed mutes the tab badge), not per-item read state. |

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

### 3.10 Notifications (NOTIF)

See [ADR-0006](./adr/0006-notifications-v1-polling.md).

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-NOTIF-001 | Must | In the foreground, a polling worker fetches notification data on a sensible interval (default 60 s, backoff on error) and updates in-app badges. |
| FR-NOTIF-002 | Must | The Kajüte, Forum, Nachrichten and ToDos tabs reflect unread counts as returned by Discourse / meine-piraten. |
| FR-NOTIF-003 | Must | A BGAppRefreshTask (requested cadence 30 min) polls all six volatile sources (Forum, Messages, News, ToDos, Knowledge, Events). Each source is polled independently so a failure in one does not block the others. |
| FR-NOTIF-004 | Must | When the background task finds new activity in a category for which the user has enabled notifications (see FR-PROF-002), a local iOS notification (banner + sound) is dispatched. See [OPEN-12](./open-issues.md) — the current code does not dispatch local notifications from the background task; this must be fixed before v1 ship. |

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
