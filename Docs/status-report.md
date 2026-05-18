# MeinePIRATEN iOS — Codebase Status Report

**Captured:** 2026-04-20
**Branch surveyed:** `main` at commit `f9a269c`
**Purpose:** factual snapshot of what the code does today, for gap
analysis against the separately produced requirements / architecture
docs. No edits were made.

---

## 1. Project shell

### Repo tree (2 levels)

```
./
├── CLAUDE.md
├── Config/
│   └── Secrets.xcconfig           (gitignored; sample file missing)
├── Docs/                           (10 Markdown files, see below)
├── PIRATEN/                        (app source)
│   ├── App/
│   ├── Core/
│   ├── Docs/                       (contains one MD inside the app dir)
│   ├── Info.plist
│   ├── PIRATEN.entitlements
│   └── Resources/
├── PIRATEN.xcodeproj/
│   └── project.xcworkspace/…/swiftpm/Package.resolved
├── PIRATENTests/                   (24 Swift test files)
│   └── Domain/
├── PIRATENUITests/                 (2 Swift files)
├── README.md
├── scripts/
│   └── ralph/                      (autonomous agent assets)
├── .gitignore
└── .mcp.json
```

### Xcode / Swift

| Item | Value |
|---|---|
| Project | `PIRATEN.xcodeproj` (no `.xcworkspace` of its own) |
| Scheme | `PIRATEN` (only one) |
| Deployment target | `IPHONEOS_DEPLOYMENT_TARGET = 26.2` |
| Swift version | `SWIFT_VERSION = 5.0` |
| Platforms | `SUPPORTED_PLATFORMS = iphoneos iphonesimulator` |
| Device family | Two configs present: `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad) and `TARGETED_DEVICE_FAMILY = 1` (iPhone only) |
| Marketing version | `1.0` |
| Current project version | `17` (bumped from `14` on this branch) |
| Orientation iPhone | Portrait + LandscapeL/R |
| Orientation iPad | All four |

### Dependency manager

Swift Package Manager only. No `Podfile`, no `Cartfile`, no `Package.swift`
at repo root. Single pinned dependency in
`PIRATEN.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`:

| Package | Version | Repo |
|---|---|---|
| AppAuth-iOS | `1.7.6` | `github.com/openid/AppAuth-iOS.git` |

### Configuration & secrets

- `Config/Secrets.xcconfig` exists **on disk**; it is gitignored
  (`.gitignore` line `Config/Secrets.xcconfig`). Keys present
  (values redacted):
  - `SSO_CLIENT_ID`, `SSO_REDIRECT_URI` (two commented-out
    `SSO_AUTHORIZATION_ENDPOINT` / `SSO_TOKEN_ENDPOINT`)
  - `KEYCLOAK_BASE_URL`
  - `DISCOURSE_BASE_URL`, `DISCOURSE_CLIENT_ID`,
    `DISCOURSE_AUTH_REDIRECT_SCHEME`, `DISCOURSE_AUTH_REDIRECT_HOST`,
    `DISCOURSE_APP_NAME`
  - `KNOWLEDGE_REPO_OWNER`, `KNOWLEDGE_REPO_NAME`, `KNOWLEDGE_REPO_BRANCH`
  - `MEINE_PIRATEN_BASE_URL`
  - `AGITATORRR_BASE_URL`
- `Config/Secrets.sample.xcconfig` is **missing**, even though
  `README.md` instructs `cp Config/Secrets.sample.xcconfig Config/Secrets.xcconfig`.

### Top-level files

| File | Present | Notes |
|---|---|---|
| `README.md` | Yes | 9.3 KB, bilingual headings; feature status table slightly stale vs code (says "Posting/Replies not started" but `replyToForumPost` exists in the repo protocol) |
| `LICENSE` | **No** | |
| `CONTRIBUTING.md` | **No** | |
| `.gitignore` | Yes | Ignores `.env`, `CLAUDE.md` (except `scripts/ralph/CLAUDE.md`), `/scripts/*` (except `/scripts/ralph`), `.mcp.json`, `.claude/`, `DerivedData/`, `*.xcuserstate`, `.DS_Store`, `Config/Secrets.xcconfig`. Notably does **not** ignore `.build/` which is currently untracked in the working copy. |
| `Docs/` | Yes (10 files) | `API_REQUEST_MAP.md`, `CI_NOTES.md`, `DECISIONS.md` (~48 KB), `NOTIFICATIONS_TODO.md`, `OPEN_QUESTIONS.md`, `PROJECT_STATUS.md`, `PUSH_NOTIFICATIONS_RAILS_PRD.md`, `RELEASE_CHECKLIST.md`, `THREAT_MODEL.md`, `Wissen-Tab-Darstellungskonzept.md` |

---

## 2. High-level architecture as implemented

### Top-level source folders

| Path | Purpose (one line) |
|---|---|
| `PIRATEN/App/` | SwiftUI entry point, views, view-models, theme |
| `PIRATEN/App/Theme/` | Fonts, colors, component modifiers |
| `PIRATEN/App/ViewModels/` | 18 `ObservableObject` view-models, one per feature / screen |
| `PIRATEN/App/Views/Auth/` | `LoginView` only |
| `PIRATEN/App/Views/Startup/` | App launch + auth-state routing |
| `PIRATEN/App/Views/Main/` | 25 feature screens (Home, Forum, Messages, …) |
| `PIRATEN/App/Views/Knowledge/Components/` | Lesson widgets (checklist, quiz, callouts …) |
| `PIRATEN/Core/Data/` | Repository implementations, API clients, DTOs, storage, OIDC, HTTP, notifications |
| `PIRATEN/Core/Domain/` | Entity types + repository protocols |
| `PIRATEN/Core/Support/` | Keychain, AppContainer, redactor, HTML parsing, misc system wrappers |
| `PIRATEN/Resources/` | `Assets.xcassets`, fonts, icons |

### Layer separation

Clean separation is real and enforced by convention:

- Views consume `@ObservedObject` ViewModels only; no `URLSession` calls
  in views.
- ViewModels depend on **repository protocols** in `Core/Domain/*`,
  never on concrete implementations. Every feature has a `FakeXxxRepository`
  alongside `RealXxxRepository` (Auth, Calendar, Discourse, Knowledge,
  News, Todos).
- `Core/Data/HTTP/` is a layered HTTP stack:
  `URLSessionHTTPClient` → `RetryingHTTPClient` (wrapper) →
  `AuthenticatedHTTPClient` / `DiscourseHTTPClient` (auth-injecting
  wrappers). `StubHTTPClient` exists for tests.
- DTOs live in `Core/Data/**/*DTO.swift`, mapped into domain models
  inside the `Real…Repository` (see e.g. `DiscourseDTO.swift` 721 LOC).

### UI framework

SwiftUI-first. `import UIKit` appears only in `AppDelegate`,
`NotificationSettingsManager`, `SelectableTextView` (UIViewRepresentable
bridge), `PiratenAppearance` (bar appearance). Roughly 100 % of
feature screens are SwiftUI.

### Composition root

- `@main` is `PIRATEN/App/PIRATENApp.swift`.
- `PIRATENApp.init()` constructs `AppContainer()` and stores it both as
  an instance property and as `AppContainer.shared` (singleton escape
  hatch, used by `BackgroundTaskScheduler`).
- All ViewModels + services are built in `PIRATEN/Core/Support/AppContainer.swift`
  (511 LOC). Constructor injection throughout — no `@EnvironmentObject`
  for DI, no property wrappers driving resolution.
- `PIRATENApp` injects a large set of ViewModels + factory closures into
  `StartupContainerView`, which hands them to `RootView` /
  `MainTabView`.

### Mapping to documented layering

| Documented layer | Concrete type(s) |
|---|---|
| HTTPClient | `Core/Domain/HTTP/HTTPClient.swift` (protocol) + `URLSessionHTTPClient`, `RetryingHTTPClient`, `AuthenticatedHTTPClient`, `DiscourseHTTPClient`, `StubHTTPClient` |
| TokenStore | `Core/Support/KeychainService.swift` (`CredentialStore` protocol + `KeychainCredentialStore`) |
| Cache | `Core/Data/Storage/DiscourseCacheStore.swift`, `NewsCacheStore.swift`, `MessageDraftStore.swift`, `RecentRecipientsStore.swift`, `ReadingProgressStore.swift`, plus `Core/Data/Knowledge/KnowledgeCacheManager.swift` |
| Logger | **Absent as a first-class abstraction.** One `os.Logger` instance in `DiscourseAuthManager`, scattered `print(...)` in ~6 places, `Core/Support/LogRedactor.swift` exists as a string utility |
| Feature services | `Real<Feature>Repository` in `Core/Data/<Feature>/`, backed by a `<Feature>APIClient` |
| Upstream adapters | OIDC via AppAuth in `Core/Data/OIDC/*`, Discourse in `Core/Data/Discourse/*`, GitHub in `Core/Data/Knowledge/GitHubAPIClient.swift`, iCal in `Core/Data/Calendar/*`, news JSON in `Core/Data/News/NewsAPIClient.swift`, meine-piraten.de in `Core/Data/Todos/TodoAPIClient.swift` |
| Staleness gate | `Core/Support/StalenessGuard.swift` (added on this branch) |

---

## 3. Feature-by-feature status

### Authentication (PiratenSSO)
- **Status:** Working
- **Files:** `Core/Data/OIDC/AppAuthOIDCAuthService.swift`,
  `AppAuthOIDCDiscoveryService.swift`, `AppAuthTokenRefresher.swift`,
  `Core/Data/Auth/OIDCAuthRepository.swift`,
  `Core/Domain/Auth/*`, `Core/Support/KeychainService.swift`,
  `Core/Support/IDTokenParser.swift`, `App/Views/Auth/LoginView.swift`
- **Observable behaviour:** Tapping "Mit Piratenlogin anmelden" opens
  `ASWebAuthenticationSession`, completes OAuth2/OIDC PKCE against
  Keycloak, persists tokens to Keychain, auto-refreshes before expiry,
  and surfaces the authenticated user profile.

### Kajüte (Home)
- **Status:** Working
- **Files:** `App/Views/Main/HomeView.swift`,
  `App/ViewModels/HomeViewModel.swift`
- **Observable behaviour:** Home tab showing greetings, toolbar buttons
  for notifications / messages / news with badge support, entry points
  to forum topics / knowledge topics / todos via shared factories.

### Forum
- **Status:** Working (list + read + reply + like + read-state)
- **Files:** `App/Views/Main/ForumView.swift`,
  `TopicDetailView.swift`, `CategoryDetailView.swift`,
  `ReplyComposerView.swift`, `App/ViewModels/ForumViewModel.swift`,
  `TopicDetailViewModel.swift`,
  `Core/Domain/Discourse/DiscourseRepository.swift`,
  `Core/Data/Discourse/RealDiscourseRepository.swift` (436 LOC),
  `DiscourseAPIClient.swift` (652 LOC)
- **Observable behaviour:** Topic list cache-first (instant render from
  `DiscourseCacheStore`), pull-to-refresh, tap into topic detail with
  full post thread, reply composer, like / unlike posts, read-state
  persisted per topic. Note: `README.md` still claims "Posting/Replies
  not started" — code contradicts this.

### Nachrichten (private messages)
- **Status:** Working
- **Files:** `MessagesView.swift`, `MessageThreadDetailView.swift`,
  `ComposeMessageView.swift`, `RecipientPickerView.swift`,
  `App/ViewModels/MessagesViewModel.swift`,
  `MessageThreadDetailViewModel.swift`, `ComposeMessageViewModel.swift`,
  `RecipientPickerViewModel.swift`,
  `Core/Data/Storage/MessageDraftStore.swift`,
  `RecentRecipientsStore.swift`
- **Observable behaviour:** Inbox + sent (dedup + merge), thread detail,
  compose with typeahead recipient picker, draft persistence, reply,
  mark-as-read. Tab-switch loads only fetch inbox on this branch; pull-
  to-refresh fetches both halves.

### Wissen (Knowledge / Kanon)
- **Status:** Working
- **Files:** `KnowledgeView.swift`, `KnowledgeTopicDetailView.swift`,
  `App/Views/Knowledge/Components/{Callout,Checklist,MarkdownText,
  NextSteps,Overview,Quiz,Section}.swift`,
  `KnowledgeViewModel.swift`, `KnowledgeTopicDetailViewModel.swift`,
  `Core/Data/Knowledge/{RealKnowledgeRepository,GitHubAPIClient,
  FrontmatterParser,ContentSectionParser,KnowledgeCacheManager}.swift`,
  `Core/Domain/Knowledge/{KnowledgeCategory,KnowledgeIndex,
  KnowledgeTopic,TopicContent,QuizQuestion,ReadingProgress}.swift`
- **Observable behaviour:** Fetches lesson index + Markdown content from
  the `sebulino/PIRATEN-Kanon` GitHub repo, renders frontmatter + typed
  section cards, supports multiple-choice quizzes (`QuizCard`),
  checklists, offline cache, and per-topic reading-progress persistence.

### Termine (Calendar)
- **Status:** Working
- **Files:** `CalendarView.swift`, `CalendarViewModel.swift`,
  `Core/Data/Calendar/{CalendarAPIClient,ICalParser,
  RealCalendarRepository,FakeCalendarRepository}.swift`,
  `Core/Domain/Calendar/{CalendarEvent,CalendarRepository}.swift`
- **Observable behaviour:** Fetches + parses the Agitatorrr iCal feed,
  lists upcoming events, pull-to-refresh, new-content indicator.

### ToDos
- **Status:** Working
- **Files:** `TodosView.swift`, `TodoDetailView.swift`,
  `CreateTodoView.swift`, `App/ViewModels/{TodosViewModel,
  TodoDetailViewModel,CreateTodoViewModel}.swift`,
  `Core/Data/Todos/{RealTodoRepository,FakeTodoRepository,
  TodoAPIClient,TodoDTO,TodoAPIError}.swift`,
  `Core/Domain/Todos/{Todo,TodoCategory,TodoComment,Entity,
  TodoRepository}.swift`
- **Observable behaviour:** Live against meine-piraten.de `tasks.json`
  with bearer-token auth. List, detail, create, claim, complete,
  comment. README's "stubbed (fake data)" note is stale; the real
  repository is wired in `AppContainer`.

### News
- **Status:** Working
- **Files:** `NewsView.swift`, `NewsCardView.swift`, `NewsDetailView.swift`,
  `NewsViewModel.swift`, `Core/Data/News/{RealNewsRepository,
  NewsAPIClient,FakeNewsRepository}.swift`,
  `Core/Data/Storage/NewsCacheStore.swift`,
  `Core/Domain/News/{NewsItem,NewsRepository}.swift`
- **Observable behaviour:** Fetches `meine-piraten.de/api/news`
  cache-first, renders summary cards + detail, marks tab as viewed
  via `lastSeenNewsKey` / `messageId`.

### Profil
- **Status:** Working
- **Files:** `ProfileView.swift`, `UserProfileView.swift`,
  `ProfileViewModel.swift`, `UserProfileViewModel.swift`,
  `PrivacyView.swift`, `FeedbackComposeView.swift`,
  `AdminRequestView.swift`, `NotificationsSheetView.swift`
- **Observable behaviour:** Shows logged-in user (from ID token claims
  `sub`, `preferred_username`, `name`, `email`, `member_number`),
  per-category notification toggles, privacy page, logout. Separate
  `UserProfileView` for viewing other members (Discourse user card).

### Notifications
- **Status:** Partial
- **Files:** `Core/Data/Notifications/{DiscourseNotificationPoller,
  BackgroundTaskScheduler}.swift`,
  `Core/Support/NotificationSettingsManager.swift`,
  `App/AppDelegate.swift`, `App/Views/Main/MainTabView.swift`
  (foreground timer + `.onChange` scheduling),
  `App/Views/Main/NotificationsSheetView.swift`
- **Observable behaviour:** While the app is in the foreground and any
  category is enabled, a 60 s `Timer` hits
  `GET /notifications/totals.json` and updates the app-icon badge. In
  the background, iOS fires a `BGAppRefreshTask` (requested cadence
  30 min) that runs the same aggregate call. **Local notifications are
  never scheduled from the background path**; the `scheduleLocalNotification`
  code lives in SwiftUI `.onChange` observers on `MainTabView`, which
  only fire while the app is running. Per-category toggles gate display,
  not what gets polled. Todos and News are never polled in the
  background. Documented in detail in `Docs/NOTIFICATIONS_TODO.md`.

---

## 4. External integrations as implemented

All base URLs are pulled from `Info.plist` keys populated from
`Config/Secrets.xcconfig` at build time.

### PiratenSSO (Keycloak, via AppAuth-iOS)

| Item | Value |
|---|---|
| Base URL | `https://sso.piratenpartei.de/realms/Piratenlogin` (`KEYCLOAK_BASE_URL`) |
| Endpoints called | `GET /.well-known/openid-configuration`, browser authorize (opaque), `POST /protocol/openid-connect/token` (code + refresh) |
| Auth attachment | PKCE on authorize; `grant_type` + `code_verifier` / `refresh_token` in token-endpoint form body |
| Retry / backoff | `URLSessionHTTPClient` default (no custom retry on OIDC — AppAuth handles its own networking) |
| Parsing | AppAuth's `OIDServiceConfiguration`, `OIDTokenResponse`; id_token claims parsed by `Core/Support/IDTokenParser.swift` |

### Discourse

| Item | Value |
|---|---|
| Base URL | `https://diskussion.piratenpartei.de` (`DISCOURSE_BASE_URL`) |
| Endpoints called | `GET /user-api-key/new` (browser), `GET /latest.json`, `GET /t/{id}.json`, `POST /posts.json`, `POST /post_actions.json`, `GET /topics/private-messages/{user}.json`, `GET /topics/private-messages-sent/{user}.json`, `GET /users/{user}.json`, `GET /u/search/users.json`, `GET /notifications/totals.json`, `POST /t/{id}/invite`, `POST /t/{id}/notifications`, others in `DiscourseAPIClient.swift` (652 LOC) |
| Auth attachment | `User-Api-Key: <rsa-decrypted key>` header injected by `DiscourseHTTPClient` |
| Retry / backoff | `RetryingHTTPClient` wraps it: max 3 attempts, 1 s then 2 s, GET only, transient + 5xx; 429 is **not** explicitly handled (only by the new staggered startup + `StalenessGuard`) |
| Parsing | `DiscourseDTO.swift` (721 LOC) → domain models in `Core/Domain/Discourse/{Topic,Post,MessageThread,UserProfile,UserSummary,UserSearchResult}.swift` |

### meine-piraten.de — News

| Item | Value |
|---|---|
| Base URL | `https://meine-piraten.de` (`MEINE_PIRATEN_BASE_URL`) |
| Endpoint | `GET /api/news` |
| Auth | None (public) |
| Retry / backoff | Via `RetryingHTTPClient` wrapper |
| Parsing | `NewsAPIClient.swift` → `NewsItem` |

### meine-piraten.de — Todos

| Item | Value |
|---|---|
| Base URL | `https://meine-piraten.de` |
| Endpoints | `GET /tasks.json`, `GET /entities.json`, `GET /categories.json`, task create / update / comment endpoints in `TodoAPIClient.swift` (213 LOC) |
| Auth | `Authorization: Bearer <SSO access_token>` via `AuthenticatedHTTPClient` + `AuthStateTokenProvider` |
| Retry / backoff | `RetryingHTTPClient` wrapper; 401 maps to `TodoError.unauthorized` and triggers `AuthStateManager.logout()` in `TodosViewModel` |
| Parsing | `TodoDTO.swift` → `Todo`, `TodoCategory`, `Entity`, `TodoComment` |

### Agitatorrr (iCal calendar)

| Item | Value |
|---|---|
| Base URL | `https://agitatorrr.de` (`AGITATORRR_BASE_URL`) |
| Endpoint | `GET /api/veranstaltung/ical` |
| Auth | None |
| Retry / backoff | `RetryingHTTPClient` wrapper |
| Parsing | `ICalParser.swift` (212 LOC, hand-rolled VEVENT parser) → `CalendarEvent` |

### GitHub (PIRATEN-Kanon)

| Item | Value |
|---|---|
| Base URL | `https://api.github.com` |
| Repo targeted | `{KNOWLEDGE_REPO_OWNER}/{KNOWLEDGE_REPO_NAME}@{KNOWLEDGE_REPO_BRANCH}` (default `sebulino/PIRATEN-Kanon@main`) |
| Endpoints | `GET /repos/{owner}/{repo}/contents/{path}?ref={branch}` (JSON listing + Base64 blobs) |
| Auth | None (public, anonymous — subject to unauthenticated rate limits) |
| Retry / backoff | `RetryingHTTPClient` wrapper; cached on-disk by `KnowledgeCacheManager` |
| Parsing | `FrontmatterParser.swift` (YAML-ish) + `ContentSectionParser.swift` for typed Markdown section blocks |

---

## 5. Data and persistence

No SQLite / GRDB / SwiftData / Core Data. Storage is split between
UserDefaults and on-disk JSON blobs.

| Store | File | Backing | Content |
|---|---|---|---|
| `DiscourseCacheStore` | `Core/Data/Storage/DiscourseCacheStore.swift` | `UserDefaults` (JSON-encoded) | `topics: [Topic]`, `messageThreads: [MessageThread]` |
| `NewsCacheStore` | `.../NewsCacheStore.swift` | `UserDefaults` (JSON-encoded) | `items: [NewsItem]` |
| `MessageDraftStore` | `.../MessageDraftStore.swift` | `UserDefaults` | Per-thread draft strings + compose draft |
| `RecentRecipientsStore` | `.../RecentRecipientsStore.swift` | `UserDefaults` | Recent recipient usernames |
| `ReadingProgressStore` | `.../ReadingProgressStore.swift` | `UserDefaults` | Per-topic reading progress (Knowledge) |
| `KnowledgeCacheManager` | `Core/Data/Knowledge/KnowledgeCacheManager.swift` | Filesystem (app support dir) | Cached Markdown + frontmatter for Kanon topics |
| Keychain | `Core/Support/KeychainService.swift` | iOS Keychain, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` | OIDC access / refresh / id tokens, token expiration, Discourse User API Key |

### Which features cache vs go to network

| Feature | Cache-first | Network-only |
|---|---|---|
| Forum | ✅ (`DiscourseCacheStore.topics`) | |
| Messages | ✅ (`DiscourseCacheStore.messageThreads`) | |
| News | ✅ (`NewsCacheStore`) | |
| Knowledge | ✅ (on-disk `KnowledgeCacheManager`) | |
| Calendar | | ✅ |
| Todos | | ✅ |
| Profile | | ✅ |
| Notifications totals | | ✅ (last-known total in UserDefaults for comparison only) |

### Migrations

None. All JSON-encoded caches are best-effort (decode failure → treated
as empty). UserDefaults keys are untyped strings defined inline per store.

---

## 6. Cross-cutting concerns

### HTTP client

Single shared protocol `Core/Domain/HTTP/HTTPClient.swift`
(`execute(_ request: HTTPRequest) async throws -> HTTPResponse`). Every
feature goes through it via the decorator chain:

```
URLSessionHTTPClient
  └── RetryingHTTPClient   (max 3 attempts, 1s/2s backoff, GET only)
        └── AuthenticatedHTTPClient   (bearer token; meine-piraten.de)
        └── DiscourseHTTPClient        (User-Api-Key; Discourse)
```

There are **no raw `URLSession` call sites** in features — all feature
networking is mediated by the protocol. Grep for `URLSession\(` outside
`Core/Data/HTTP/` returns zero matches.

### Logging

No unified logger. Mix of:

- `os.Logger` — exactly one subsystem instance in
  `DiscourseAuthManager.swift:13` (`subsystem: "de.meine-piraten.PIRATEN"`,
  `category: "DiscourseAuth"`)
- `print(...)` — 7 sites across `AppDelegate`, `StubHTTPClient`,
  `BackgroundTaskScheduler`, `DiscourseNotificationPoller` (the latter
  inside `#if DEBUG`), `AuthStateManager`
- `Core/Support/LogRedactor.swift` — string utility for redacting
  tokens / PII, but callers are sparse

### Secrets / config

`Config/Secrets.xcconfig` → Info.plist substitution at build time →
`Bundle.main.object(forInfoDictionaryKey: …)` read in `AppContainer`
constructors. Keys listed in §1.

### Keychain

Exclusively via `KeychainCredentialStore` in
`Core/Support/KeychainService.swift`. Five keys used:

| Key | Writer | Value |
|---|---|---|
| `oidc_access_token` | `OIDCAuthRepository` | JWT access token |
| `oidc_refresh_token` | `OIDCAuthRepository` | Refresh token |
| `oidc_id_token` | `OIDCAuthRepository` | ID token (JWT) |
| `oidc_token_expiration` | `OIDCAuthRepository` | ISO-8601 string |
| `DiscourseAuthManager.discourseCredentialKey` | `KeychainDiscourseAPIKeyProvider` | Decrypted Discourse User API Key |

All writes use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. No
logging of stored values.

### Error surfaces

- Predominantly **inline states**: each ViewModel exposes `loadState`
  with `.idle / .loading / .loaded / .error(message: String)`. Views
  switch on it (`ForumView.swift:75`, `MessagesView.swift:58`, …).
- `.alert(...)` appears in only 2 views: `AdminRequestView.swift`,
  `ComposeMessageView.swift` (user-facing confirmation / validation).
- 401 from Todos → `authStateManager.logout()` (silent).
- Polling failures inside `DiscourseNotificationPoller.poll()` are
  intentionally silent with a `#if DEBUG print`.

---

## 7. Tests, CI, tooling

### Tests

- 24 files in `PIRATENTests/` (1 sub-file under `Domain/`)
- 2 files in `PIRATENUITests/`
- **~228 individual `@Test` / `func test…` cases** (`grep`-counted;
  actual run count may differ slightly)
- Coverage spread (by filename):
  - Networking / auth: `HTTPClientTests`, `DiscourseAuthManagerTests`,
    `DiscourseReplyTests`, `DiscourseNotificationPollerTests`,
    `KeychainServiceTests`, `RSAKeyManagerTests`
  - ViewModels: `CalendarViewModelTests`, `FeedbackViewModelTests`,
    `HomeViewModelTests`, `NewsViewModelTests`
  - Parsers: `ContentSectionParserTests`, `FrontmatterParserTests`,
    `ICalParserTests`, `EmojiShortcodeTests`
  - Storage: `ReadingProgressStoreTests`, `NewsAPIClientTests`
  - Cross-cutting: `DeepLinkTests`, `DeepLinkRouterTests`,
    `NotificationSettingsManagerTests`, `StalenessGuardTests` (new),
    `PIRATENTests.swift` (skeleton)
  - Domain: `Domain/UserProfileTests.swift`
- UI tests are the Xcode templates: `PIRATENUITests.swift`,
  `PIRATENUITestsLaunchTests.swift`. No snapshot tests, no screenshot
  libraries.

### CI

- No `.github/workflows/` directory.
- No Fastfile.
- No Xcode Cloud config committed.
- `Docs/CI_NOTES.md` documents the expected local `xcodebuild`
  commands (pinned simulator UDID `F0291949-CCB9-4C91-B947-292F98247041`,
  iPhone 16 / iOS 26.2). This is a **script-ish doc, not an actual CI
  pipeline**.

### Lint / format

- No `.swiftlint.yml`, no `.swiftformat`.
- No pre-commit hook configured.

### Local run

1. Copy `Config/Secrets.sample.xcconfig` → `Config/Secrets.xcconfig`
   — **but the sample file does not exist in the repo**, so the first
   run requires hand-authoring it from the README key table.
2. Open `PIRATEN.xcodeproj`, select the `PIRATEN` scheme, run on
   iPhone 16 simulator.
3. Build verified locally today (2026-04-20) on iPhone 16 iOS 26.2
   after one-time `xcodebuild -runFirstLaunch` to repair a broken
   `IDESimulatorFoundation` plugin.

---

## 8. Localisation and accessibility

### Strings

- **No `.strings` or `.xcstrings` files exist.** (`find PIRATEN -name "*.strings" -o -name "*.xcstrings"` returns nothing.)
- `LocalizedStringKey` / `NSLocalizedString` / `String(localized:)` /
  `LocalizedStringResource` — **0 occurrences** anywhere in
  `PIRATEN/**/*.swift`.
- All user-facing text is hardcoded German string literals inside the
  views (e.g. `"Neue Nachrichten"`, `"Aufgaben konnten nicht geladen
  werden. Bitte überprüfe deine Verbindung."`).
- Info.plist orientation keys and bundle settings are English defaults.

### Accessibility

- 102 `accessibilityLabel` / `accessibilityHint` / `accessibilityValue`
  / `accessibilityIdentifier` / `dynamicTypeSize` / `.accessibility*`
  occurrences across **21 files** (roughly all tab-level screens +
  Knowledge components + compose flows + login).
- Base ≥ 10 usages in `TopicDetailView`, `MessageThreadDetailView`,
  `TodosView`, `MessagesView`, `KnowledgeView`.
- `PROJECT_STATUS.md` M9 entry claims "VoiceOver labels, Dynamic Type
  support, and contrast fixes across core flows" — consistent with the
  grep numbers.
- No explicit tap-target size assertions (e.g. 44×44) could be grep'd.

---

## 9. Known issues and TODOs in the code

### Comment markers

Exactly **one** TODO in `PIRATEN/**/*.swift`:

```
PIRATEN/Core/Data/Discourse/DiscourseDTO.swift:704:
    // TODO: Move field ID to xcconfig once confirmed (see OPEN_QUESTIONS.md).
```

No `// FIXME`, no `// HACK`, no `// XXX` markers.

### Forced casts / force-unwraps

Two `as!` sites, both narrow and defensible:

```
PIRATEN/Core/Data/Notifications/BackgroundTaskScheduler.swift:12
    BGTaskScheduler.shared.register(forTaskWithIdentifier: …) { task in
        self.handleAppRefresh(task: task as! BGAppRefreshTask)
    }
```
(Task is guaranteed `BGAppRefreshTask` by the matching identifier
registration — standard BackgroundTasks idiom.)

```
PIRATEN/Core/Support/RSAKeyManager.swift:96
    return (item as! SecKey)
```
(Keychain `SecItemCopyMatching` returns `AnyObject`; guaranteed
`SecKey` class from the query.)

No `fatalError(...)` anywhere in `PIRATEN/**/*.swift`.

### Placeholder / disabled code worth flagging

```
PIRATEN/Core/Domain/Auth/AuthStateManager.swift:128
    print("WARNING: handleAuthenticationError() called but is disabled")
```
A published auth error handler is intentionally inert. Code itself
announces this; callers are unknown without further investigation.

```
PIRATEN/Core/Data/HTTP/StubHTTPClient.swift (print in production-ish location)
PIRATEN/Core/Data/Notifications/BackgroundTaskScheduler.swift:23
    print("Could not schedule app refresh: \(error)")
```
Both are non-guarded `print` (no `#if DEBUG`), so they ship.

### Comments that warn about themselves

- Extensive caveats in `DiscourseAuthManager.swift` about RSA key
  persistence + nonce validation.
- `DiscourseCacheStore.swift`, `NewsCacheStore.swift` note "best-effort"
  semantics; decode failures are swallowed silently.

---

## 10. Things that surprised you

- **Clean Architecture is actually enforced, not nominal.** Every
  feature has `Real*Repository` + `Fake*Repository` + `*APIClient` +
  `*DTO`. Protocols live in `Core/Domain/*`. Views never touch the
  network. For a one-person v0.x project, the layering discipline is
  unusual and good.
- **Composition root is 511 LOC in a single file.** `AppContainer` is a
  hand-written DI container with a separate `testing` initialiser and
  per-ViewModel factory closures. Readable, but the surface area is
  large — adding a new feature touches this file every time.
- **Zero localisation infrastructure despite a German-only audience.**
  Every string is a hardcoded literal. Switching base language or
  adding English later is currently a codebase-wide rewrite.
- **No CI.** Given the milestone discipline in `DECISIONS.md` and a
  `RELEASE_CHECKLIST.md`, I expected at least a GitHub Actions build
  matrix. There is none — `CI_NOTES.md` documents the commands but
  nothing runs them automatically.
- **No linting.** `CLAUDE.md` mandates "clarity over cleverness" and
  reviewable steps, but SwiftLint / SwiftFormat are absent.
- **AppAuth is the only third-party dep.** Everything else — iCal parser,
  frontmatter parser, HTML parser, Markdown rendering, RSA key
  management — is hand-rolled. `DiscourseDTO.swift` alone is 721 LOC.
- **Notification system is half-wired.** The per-category toggles,
  per-section notification titles, 30-min background scheduler, foreground
  60 s timer, and `scheduleLocalNotification` helper all exist — but
  they're hooked into SwiftUI `.onChange` observers that cannot fire
  from a background `BGAppRefreshTask`. It looks like a feature, but on
  a closed device only the aggregate Discourse badge updates.
  (See `Docs/NOTIFICATIONS_TODO.md`.)
- **Three storage idioms for a "small" app.** JSON in UserDefaults
  (`DiscourseCacheStore`, `NewsCacheStore`), scalar UserDefaults
  (`ReadingProgressStore`, last-seen IDs), and filesystem JSON
  (`KnowledgeCacheManager`). No central `Cache` protocol.
- **Singleton escape hatch.** `AppContainer.shared` exists solely so
  `BackgroundTaskScheduler` can reach the poller from a non-UI context.
  Otherwise DI is clean.
- **`Secrets.sample.xcconfig` is missing.** README instructs copying it;
  it isn't there. A fresh clone can't follow the "Getting Started"
  steps literally.
- **Telegram bot token in local `Secrets.xcconfig`.** Not committed (it's
  gitignored), but the presence of a bot token in developer-local config
  for an app with no apparent Telegram feature is unexplained.
- **`.build/` is untracked and ungitignored.** Swift-build output is
  sitting in the working tree. Low-risk, but inconsistent with the rest
  of the ignore list.
- **README is stale.** It claims Forum posting / replies are not
  started; code implements them (`ReplyComposerView`, `replyToForumPost`
  in the repo protocol + `RealDiscourseRepository`).

---

## 11. Open questions back to the architect

- Is Keycloak realm + client ID intended to vary per build (dev / prod
  staging), or is the single pinned `Piratenlogin` realm correct for
  all environments?
- Is the Discourse host (`diskussion.piratenpartei.de`) fixed, or should
  it vary per build flavor?
- Should all user-facing strings be routed through a localisation
  catalog now, or is "German-only, forever" an explicit choice worth
  codifying in `DECISIONS.md`?
- What is the expected background-notification UX in detail — per-section
  local notification, per-section badge, or only the aggregate Discourse
  badge? (This is the core ambiguity in `Docs/NOTIFICATIONS_TODO.md`.)
- Should News and Todos be polled in the background at all, given they
  live on meine-piraten.de and have no cheap counter endpoint?
- Is there an authoritative unread-count source (Discourse totals +
  Todos unread + News unread), or is the iOS app-icon badge intentionally
  Discourse-only?
- Should `AppContainer.shared` be eliminated, or is the
  `BackgroundTaskScheduler` reach-through acceptable?
- Is the intention to add CI / SwiftLint later, or deliberately skip
  them while the project has a single contributor?
- Is `Secrets.sample.xcconfig` supposed to exist in-repo? If yes, what
  keys + placeholder values should it contain?
- Is there a Telegram integration planned? If yes, where should the
  bot token rotation / distribution be documented?
- `handleAuthenticationError()` in `AuthStateManager` is explicitly
  disabled — what's the intended re-enable path, and what triggers it?
- Is the Kanon GitHub repo's ownership (`sebulino/PIRATEN-Kanon`)
  permanent, or is it expected to move to a `piratenpartei` org before
  ship?
- Should the Forum category pins (if any exist in the spec) be stored
  in UserDefaults, Keychain, or fetched from Discourse user prefs?

---
