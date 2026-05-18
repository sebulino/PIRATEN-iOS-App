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

### 3.2 Kajüte — the home screen (HOME)

The *Kajüte* is the landing screen after login.

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-HOME-001 | Must | Greet the user by first name ("Ahoi \<Name\>!") and show whether there are unread private messages. |
| FR-HOME-002 | Must | Show "Letzte Kontakte" — recent people the user has exchanged DMs with. The list is derived from the cached Discourse message threads (no separate store); each contact is tappable to open the thread. |
| FR-HOME-003 | Should | Show a "Deine Meinung, egal wozu" module — a lightweight thumbs-up / thumbs-down feedback widget. Feedback is sent as a Discourse private message to the app maintainer (@sebulino). |
| FR-HOME-004 | Should | Show a "Weiterlesen" module with the last 3–5 Kanon entries the user has read, sorted by last-read date descending. Populated from `ReadingProgressStore`. |
| FR-HOME-005 | Should | Show "Übernommene Aufgaben" — the ToDos the user has personally taken on. |

### 3.3 Forum (FORUM)

| ID | MoSCoW | Requirement |
|---|---|---|
| FR-FORUM-001 | Must | List topics with unread activity first, showing title, author, last-activity timestamp, reply count and view count. |
| FR-FORUM-002 | Must | Tapping a topic opens the post list with threaded replies. |
| FR-FORUM-003 | Must | The user can post a reply (plain markdown, same flavour Discourse accepts). |
| FR-FORUM-004 | Must | The user can like and unlike individual posts, and the state is synced to Discourse (not displayed optimistically only). See [OPEN-02](./open-issues.md) — current implementation does not sync likes upstream; this must be fixed before v1 ship. |
| FR-FORUM-005 | Must | The user can pin Discourse categories (e.g. their Landesverband). Pin state is stored in UserDefaults, device-local only. |
| FR-FORUM-006 | Must | Inline image rendering for posts. Images must render at their natural aspect ratio — never stretched beyond their actual dimensions. |
| FR-FORUM-007 | Must | Reading a topic marks it as read on Discourse so read state is consistent across devices. |
| FR-FORUM-008 | Should | The user can create a new forum topic. |

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
