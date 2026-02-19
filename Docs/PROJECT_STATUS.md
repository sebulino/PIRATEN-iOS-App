# Project Status

Last updated: 2026-02-19 (Kajüte + Termine tabs)

## Current Milestone

**Milestone 8: Knowledge Hub (Wissen)** — Complete

Goal: Fetch educational content from the public GitHub repo sebulino/PIRATEN-Kanon, cache it locally, and present interactive lessons with progress tracking, quizzes, and checklists.

## Recent Enhancements

### Kajüte (Home) and Termine (Calendar) Tabs (2026-02-19)
**Status:** Complete ✅

Added two new tabs to the app, bringing the total to 6:

**Kajüte (Home) — Tab 0:**
- Dashboard view aggregating data from existing sources
- Section 1 "Letzte Kontakte": Horizontal avatar scroll from message thread participants
- Section 2 "Weiterlesen": Up to 3 knowledge articles (in-progress first, then unread)
- Section 3 "Aktuelle Themen": 5 most recent forum topics
- Each section loads independently (partial data OK on failure)

**Termine (Calendar) — Tab 4:**
- Fetches iCal feed from piragitator.de (`/api/veranstaltung/ical/1/`)
- Custom ICalParser for RFC 5545 VEVENT extraction
- Two sections: "Kommende Termine" (ascending) and "Vergangene Woche" (descending)
- Event rows with title, date/time, location, category badges
- Public endpoint — no authentication required

**Tab Reordering:**
- New order: Kajüte (0), Forum (1), Nachrichten (2), Wissen (3), Termine (4), ToDos (5)
- iOS shows first 4 tabs visible + "More" menu for Termine and ToDos
- Deep link indices updated (Messages = 2, Todos = 5)

**Configuration:**
- `PIRAGITATOR_BASE_URL` added to xcconfig + Info.plist
- CalendarAPIClient uses base HTTPClient (no auth wrapper)
- AppContainer wires CalendarRepository and HomeViewModel

**Tests:** ICalParserTests, CalendarViewModelTests, HomeViewModelTests
**Docs:** DECISIONS.md D-027/D-028/D-029, OPEN_QUESTIONS.md Q-020/Q-021

### Forum Post Reply Feature (2026-02-13)
**Status:** Complete ✅

Added ability to reply to forum topics and individual posts with threaded replies.

**Implementation:**
- Domain: `Post.replyToPostNumber` field, `DiscourseRepository.replyToForumPost()` method
- Data: `DiscoursePostDTO.reply_to_post_number` parsing, `DiscourseAPIClient.replyToForumPost()` with optional `reply_to_post_number` parameter
- Presentation: `TopicDetailViewModel` reply composer state (mirroring PM reply pattern), `ReplyComposerView` extracted to shared component
- UI: Toolbar reply button (general topic reply) + per-post reply button (threaded reply), reply context banner showing target post
- Validation: `MessageSafetyService` integration (30s cooldown, 10k char limit)

**API:** Uses Discourse `POST /posts.json` with `topic_id`, `raw`, and optional `reply_to_post_number`

**Resolved:** OPEN_QUESTIONS.md Q-011

## Milestone 8 Progress

| Story ID | Title | Status |
|----------|-------|--------|
| M8-001 | Domain models and repository protocol | Complete |
| M8-002 | GitHub API client | Complete |
| M8-003 | YAML frontmatter parser | Complete |
| M8-004 | Markdown content parser | Complete |
| M8-005 | File cache manager | Complete |
| M8-006 | RealKnowledgeRepository | Complete |
| M8-007 | FakeKnowledgeRepository | Complete |
| M8-008 | ReadingProgressStore | Complete |
| M8-009 | KnowledgeViewModel (home screen) | Complete |
| M8-010 | KnowledgeTopicDetailViewModel | Complete |
| M8-011 | Reusable Knowledge UI components | Complete |
| M8-012 | KnowledgeView (home screen) | Complete |
| M8-013 | CategoryDetailView | Complete |
| M8-014 | KnowledgeTopicDetailView (lesson view) | Complete |
| M8-015 | Configuration and AppContainer wiring | Complete |
| M8-016 | Unit tests | Complete |
| M8-017 | Update project documentation | Complete |

## Completed Work

### M8-001: Domain Models
- `KnowledgeCategory`, `KnowledgeTopic`, `QuizQuestion`, `TopicContent`, `ContentSection`, `ChecklistItem`, `CalloutType` (with custom Codable)
- `ReadingProgress` with `ReadingStatus` and `TopicProgress`
- `KnowledgeIndex` with `LearningPath`
- `KnowledgeRepository` protocol (`@MainActor`) with `KnowledgeError` enum

### M8-002: GitHub API Client
- `GitHubAPIClient` with HTTPClient injection, supports ETag conditional requests (If-None-Match → 304)
- Raw file fetching via download_url
- Rate limit detection from 403 + X-RateLimit headers → `KnowledgeError.rateLimited`

### M8-003–004: Content Parsing
- `FrontmatterParser`: Parses YAML frontmatter (--- delimited), handles quoted values, lists, nested quiz dicts
- `ContentSectionParser`: Splits markdown by H2 headings into typed `ContentSection` values
- Recognizes special sections: Kurzüberblick → `.overview`, Checkliste → `.checklist`, Nächste Schritte → `.nextSteps`
- Detects callout blockquotes (TIP, ACHTUNG, MERKSATZ)

### M8-005: File Cache
- `KnowledgeCacheManager` for `<Caches>/Knowledge/` directory
- Atomic writes (temp file + rename), graceful nil on read errors

### M8-006: RealKnowledgeRepository
- Orchestrates GitHubAPIClient, parsers, and cache manager
- Cache-first with 24h TTL, ETag conditional requests
- Parallel category fetching, graceful fallback to cached data on network failure
- Ignores `_shared` and dotfolders

### M8-007: FakeKnowledgeRepository
- Hardcoded 2 categories, 4 topics, 1 sample TopicContent with all section types
- Simulates 100ms delay for previews and tests

### M8-008: ReadingProgressStore
- `ReadingProgressStorage` protocol backed by UserDefaults
- JSON-encoded `[String: TopicProgress]`, constructor-injected UserDefaults for test isolation

### M8-009–010: ViewModels
- `KnowledgeViewModel`: Loading states, client-side search, featured/in-progress topics
- `KnowledgeTopicDetailViewModel`: Content loading, checklist toggle persistence, quiz submission, progress tracking (unread → started → completed)

### M8-011: Reusable UI Components
- SectionCard (accordion), OverviewCard, ChecklistCard (interactive), CalloutView, QuizCard, NextStepsCard, MarkdownTextView
- Dynamic Type support, VoiceOver labels on interactive elements

### M8-012–014: Views
- `KnowledgeView`: Home screen with search, featured section, in-progress topics, category grid (ScrollView + LazyVStack)
- `CategoryDetailView`: Category header with topic cards showing progress status
- `KnowledgeTopicDetailView`: Lesson view rendering all section types with expand/collapse

### M8-015: Wiring
- `KNOWLEDGE_REPO_OWNER`, `KNOWLEDGE_REPO_NAME`, `KNOWLEDGE_REPO_BRANCH` in xcconfig + Info.plist
- Production AppContainer uses RealKnowledgeRepository, test uses FakeKnowledgeRepository
- Factory `makeKnowledgeTopicDetailViewModel` wired through MainTabView

### M8-016: Unit Tests
- FrontmatterParserTests, ContentSectionParserTests, ReadingProgressStoreTests
- Swift Testing framework (@Test, @testable import)

### M8-017: Documentation
- PROJECT_STATUS.md, DECISIONS.md, OPEN_QUESTIONS.md, README.md updated

## Previous Milestones

### Milestone 7: Real Todo API Integration
- REST client for meine-piraten.de Rails server
- DTOs, TodoAPIClient, RealTodoRepository
- Domain model aligned to server schema (entities, categories, comments)

### Milestone 6: Actionable Todos (Write Operations)
- Create, claim, complete, unclaim, comment, delete (hidden) for Todos
- Full UI with TodoDetailView, CreateTodoView, TodoRow
- FakeTodoRepository with in-memory data

### Milestone 5: Push Notifications
- APNs device token registration
- Deep links from notifications to Messages/Todos
- Push backend contract documentation

### Milestone 4: Private Messages
- Message threads, compose flow, recipient picker
- Recent recipients, draft storage

### Milestone 3: Forum Integration
- Discourse API client, topic listing, post viewing
- User API Key authentication for Discourse

### Milestone 2: Authentication
- SSO integration via AppAuth-iOS (OIDC/OAuth2 + PKCE)
- Token storage in Keychain, session management

### Milestone 1: Bootstrap
- Clean Architecture folder structure, auth state machine, tab bar shell
- Configuration system, Keychain service, documentation

## Blockers

See [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) for items requiring external input.
