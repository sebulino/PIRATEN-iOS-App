# Architecture — MeinePIRATEN iOS

**Document status:** Draft 0.2 · Companion to [`requirements.md`](./requirements.md)

This document describes the architecture as implemented. Individual decisions
are recorded as ADRs in [`adr/`](./adr/) and referenced inline. Rationale for
each major choice lives in [`decisions-log.md`](./decisions-log.md).

---

## 1. System context

MeinePIRATEN is a thin-ish native iOS client. It aggregates content from four
backends it does not own, plus one identity provider:

```
 ┌─────────────────────────┐
 │      iOS device         │
 │  ┌───────────────────┐  │
 │  │  MeinePIRATEN app │  │
 │  └────────┬──────────┘  │
 └───────────┼─────────────┘
             │ HTTPS
             ▼
 ┌───────────────────────────────────────────────────────┐
 │                                                       │
 │   PiratenSSO (OIDC)                                   │
 │   └─ identity, token issuance                         │
 │                                                       │
 │   diskussion.piratenpartei.de (Discourse)             │
 │   └─ forum, PMs, likes, read state, notifications     │
 │                                                       │
 │   meine-piraten.de                                    │
 │   ├─ /api/news      (news feed, public)               │
 │   ├─ /tasks.json    (ToDos, bearer-token auth)        │
 │   └─ /admin_requests (admin requests)                 │
 │                                                       │
 │   agitatorrr.de                                       │
 │   └─ /api/veranstaltung/ical (iCal event feed)        │
 │                                                       │
 │   github.com/sebulino/PIRATEN-Kanon                   │
 │   └─ knowledge content (raw files, anonymous)         │
 │                                                       │
 └───────────────────────────────────────────────────────┘
```

No server component is owned by the app itself in v1
(see [ADR-0004](./adr/0004-no-app-specific-backend-v1.md)).

---

## 2. Layers inside the app

```
┌─────────────────────────────────────────────────────┐
│  Presentation (SwiftUI Views + ViewModels)          │
│    Kajüte · Forum · Wissen · Termine · ToDos · …    │
├─────────────────────────────────────────────────────┤
│  Feature services                                   │
│    AuthRepository · DiscourseRepository ·           │
│    KnowledgeRepository · CalendarRepository ·       │
│    TodoRepository · NewsRepository                  │
├─────────────────────────────────────────────────────┤
│  Core                                               │
│    HTTP client · Token store (Keychain) ·           │
│    JSON stores · Logger · Scheduler                 │
├─────────────────────────────────────────────────────┤
│  Upstream adapters (one per external system)        │
│    DiscourseAPIClient · CalendarAPIClient ·         │
│    TodoAPIClient · NewsAPIClient ·                  │
│    GitHubAPIClient · AppAuthOIDCAuthService         │
└─────────────────────────────────────────────────────┘
```

Guiding principles:

- **Feature services never import upstream adapters across boundaries.** A
  `DiscourseRepository` uses `DiscourseAPIClient`, never `GitHubAPIClient`.
  This keeps failure modes isolated (NFR-005).
- **Views do not do networking.** Views render state; ViewModels orchestrate;
  repositories hold policy; adapters translate.
- **Repository pattern with Real/Fake split.** Every feature exposes a
  protocol in `Core/Domain/<Feature>`. `Real<Feature>Repository` is wired
  into `AppContainer` in dev and production. `Fake<Feature>Repository`
  exists in test targets only — never in the running app. Loading and
  empty states are rendered as skeleton / placeholder UI, never as fake
  data (NFR-016).
- **Cache is a first-class dependency**, not an afterthought. Every feature
  that renders content renders it from its cache. The network fills the
  cache. See [ADR-0010](./adr/0010-v1-cache-in-userdefaults-and-filesystem.md).

---

## 3. Cross-cutting: the HTTP client

All outbound HTTP goes through a single `HTTPClient` protocol, implemented
as a decorator chain:

```
URLSessionHTTPClient
  └── RetryingHTTPClient          (max 3 attempts, 1s/2s backoff, GET only)
        ├── AuthenticatedHTTPClient    (bearer token; meine-piraten.de)
        └── DiscourseHTTPClient        (User-Api-Key header; Discourse)
```

The HTTP stack provides:

- authenticated-request helpers that read tokens from the Keychain,
- 401 handling: for meine-piraten.de, mapped to logout; for Discourse,
  handled via the User API Key refresh flow,
- 429 handling with exponential backoff,
- structured logging of status codes (never bodies),
- `URLSession` with ephemeral caching disabled (we cache at the domain layer,
  not at the HTTP layer).

There are no raw `URLSession(...)` calls outside the `Core/Data/HTTP/` folder.

---

## 4. Cross-cutting: auth flow

### PiratenSSO (Keycloak via AppAuth-iOS)

1. User taps "Mit Piratenlogin anmelden" → `ASWebAuthenticationSession`
   opens PiratenSSO.
2. On redirect, the app receives an authorisation code.
3. The code is exchanged for an **access / refresh / ID token** triple.
4. The ID token claims (`sub`, `preferred_username`, `name`, `email`,
   `member_number`) are persisted in memory; the tokens go to the Keychain
   with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
5. Tokens do not survive device migration or iCloud restore — users
   re-authenticate on a new device.

### Discourse User API Key (see [ADR-0009](./adr/0009-discourse-user-api-key.md))

After successful PiratenSSO login, the app obtains a User API Key from
Discourse via the `/user-api-key/new` handshake:

1. The app generates an RSA key pair locally and stores the private key
   in the Keychain.
2. The app opens a browser session to `/user-api-key/new` with the public
   key and a nonce.
3. The user authorises the key.
4. Discourse returns the User API Key encrypted with the app's public key.
5. The app decrypts the key and stores it in the Keychain.
6. All subsequent Discourse requests carry `User-Api-Key: <decrypted key>`
   as injected by `DiscourseHTTPClient`.

A disabled `handleAuthenticationError()` in `AuthStateManager` is flagged
as [OPEN-09](./open-issues.md) for investigation before v1 ship.

---

## 5. Cross-cutting: notifications

See [ADR-0006](./adr/0006-notifications-v1-polling.md) for the full decision.

### Foreground

A 60-second `Timer` in the foreground path polls Discourse
`/notifications/totals.json` and updates tab-bar badges and the Kajüte.

### Background

A `BGAppRefreshTask` registered via `BackgroundTaskScheduler` polls **six
volatile sources** on a 30-minute cadence:

1. Forum activity (Discourse)
2. Private messages (Discourse)
3. News (meine-piraten.de)
4. ToDos (meine-piraten.de)
5. Knowledge / Kanon (GitHub SHA check)
6. Events / Calendar (Agitatorrr iCal)

Each source is polled independently; a failure in one does not block the
others. When new activity is found in a category for which the user has
enabled notifications (FR-PROF-002), a **local iOS notification**
(`UNMutableNotificationContent`, banner + sound) is dispatched.

**[OPEN-12](./open-issues.md) — the current code dispatches local notifications
only from SwiftUI `.onChange` observers, which cannot fire during a
BGAppRefreshTask.** The dispatch logic must move into the background task
handler before v1 ship.

### Why `AppContainer.shared` is a singleton

`AppContainer` is otherwise injected through constructors. The one exception
is a `shared` static property that `BackgroundTaskScheduler` uses to reach
the repositories. This is a deliberate, narrowly scoped accommodation of
the iOS background task lifecycle: `BGTaskScheduler` callbacks run outside
the SwiftUI view tree and have no dependency injection hook. New code must
not use `AppContainer.shared`; the exception is limited to the background
task entry points.

---

## 6. Cross-cutting: logging

A central `Logger` facade wraps `os.Logger`. Call sites look like:

```swift
Logger.forum.info("Loaded \(topics.count) topics from cache")
```

Any value that could contain user data, tokens, or PII **must** pass through
`LogRedactor` before being logged. This is enforced in code review.

There are no raw `print()` calls in shipped code. Debug-only print
statements must be wrapped in `#if DEBUG`.

---

## 7. Data model (abridged)

Only the fields the app *uses* are modelled. Discourse's API returns far more.

```swift
struct Topic { id, title, categoryId, lastPostedAt, unreadCount, replyCount, views, excerpt, authorName, authorAvatarURL }
struct Post  { id, topicId, author, bodyHTML, bodyMD, createdAt, likeCount, likedByMe }
struct PrivateMessageThread { id, participants, lastMessageAt, unread, preview }
struct UserProfile { username, avatarURL, joinedAt, postCount }
struct KanonEntry { slug, title, level, readingTimeMinutes, bodyMD, sections: [Section], quiz: [Question]? }
struct CalendarEvent { id, title, startsAt, location, linkURL, type }
struct Todo { id, title, description, category, entity, estimatedHours, dueDate, status, assignee, creatorName }
struct NewsItem { id, title, url, snippet, publishedAt, source }
```

Storage backends (see [ADR-0010](./adr/0010-v1-cache-in-userdefaults-and-filesystem.md)):

| Store | Backing | Purpose |
|---|---|---|
| `DiscourseCacheStore` | UserDefaults (JSON) | Topics, message threads |
| `NewsCacheStore` | UserDefaults (JSON) | News items |
| `ReadingProgressStore` | UserDefaults | Per-topic reading progress, quiz state |
| `MessageDraftStore` | UserDefaults | Draft messages (compose) |
| `KnowledgeCacheManager` | Filesystem (app support dir) | Markdown + frontmatter for Kanon |
| Keychain | iOS Keychain | OIDC tokens + Discourse User API Key |

All JSON stores implement a simple version-bump migration strategy
(NFR-015): each store persists a version integer; on launch, if the stored
version is outdated, the cache is cleared and data re-fetched from the network.
No data transformation is required because all cached data is re-fetchable.

---

## 8. Testability

- Repositories and API clients are protocol-based. `Fake<Feature>Repository`
  implementations live in `PIRATENTests/` only.
- ViewModels are plain Swift types and tested without a view hierarchy.
- The HTTP client has a `StubHTTPClient` for tests.
- Tests use stubs and never hit live SSO or Discourse instances.
- CI runs build + tests + lint (SwiftLint + SwiftFormat) on every PR — see
  [OPEN-06](./open-issues.md).

---

## 9. Folder layout

```
MeinePIRATEN/
├── App/                         // @main, views, view-models, theme
│   ├── ViewModels/
│   ├── Views/
│   │   ├── Auth/
│   │   ├── Startup/
│   │   ├── Main/
│   │   └── Knowledge/Components/
│   └── Theme/
├── Core/
│   ├── Domain/                  // protocols + entity types
│   │   ├── Auth/
│   │   ├── Calendar/
│   │   ├── Discourse/
│   │   ├── HTTP/
│   │   ├── Knowledge/
│   │   ├── News/
│   │   └── Todos/
│   ├── Data/                    // Real/Fake repositories + API clients
│   │   ├── Auth/
│   │   ├── Calendar/
│   │   ├── Discourse/
│   │   ├── HTTP/
│   │   ├── Knowledge/
│   │   ├── News/
│   │   ├── Notifications/
│   │   ├── OIDC/
│   │   ├── Storage/
│   │   └── Todos/
│   └── Support/                 // Keychain, AppContainer, LogRedactor, etc.
├── Resources/
│   ├── Assets.xcassets
│   └── (fonts, icons)
└── Info.plist
```
