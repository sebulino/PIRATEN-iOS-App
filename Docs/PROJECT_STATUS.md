# Project Status

Last updated: 2026-02-10 (M7 — Real Todo API Integration)

## Current Milestone

**Milestone 7: Real Todo API Integration** — Complete

Goal: Replace the fake in-memory Todo implementation with a real REST API client connected to the meine-piraten.de Rails server.

## Milestone 7 Progress

| Story ID | Title | Status |
|----------|-------|--------|
| M7-001 | Document the meine-piraten.de API | Complete |
| M7-002 | Add status and assignee to tasks (server) | Complete |
| M7-003 | Add comments model and REST API (server) | Complete |
| M7-004 | Align iOS domain model to server schema | Complete |
| M7-005 | Create DTOs and TodoAPIClient | Complete |
| M7-006 | Create RealTodoRepository | Complete |
| M7-007 | Wire RealTodoRepository in AppContainer | Complete |

## Completed Work

### M7-001–003: Server Extensions (meine-piraten-server)
- Documented all API endpoints in `docs/API_OVERVIEW.md`
- Added `status` (string, default "open") and `assignee` (string, nullable) to tasks table
- Model validation: status must be one of "open", "claimed", "done"
- Created Comments model (belongs_to :task) with nested REST endpoints
- Routes: `GET/POST /tasks/:task_id/comments.json`, `DELETE /tasks/:task_id/comments/:id.json`

### M7-004: iOS Domain Model Alignment
- Removed `OwnerType` and `Priority` enums
- `Todo` struct now uses `entityId`, `categoryId`, `urgent`, `activityPoints`, `timeNeededInHours`, `creatorName`
- Created `Entity` and `TodoCategory` domain models
- Added `fetchEntities()` and `fetchCategories()` to `TodoRepository` protocol
- Updated `createTodo` signature to take `entityId`/`categoryId`/`urgent`
- Updated all views: entity/category pickers in CreateTodoView, urgent display in detail/row
- Updated FakeTodoRepository with fake entities and categories

### M7-005: DTOs and API Client
- `TaskDTO`, `EntityDTO`, `CategoryDTO`, `CommentDTO` with snake_case CodingKeys
- Each DTO has `toDomainModel()` mapping to domain structs
- `TodoAPIClient` follows `DiscourseAPIClient` pattern (HTTPClient injection, returns Data)
- `TodoAPIError` enum with German localized descriptions
- Base URL configurable via `MEINE_PIRATEN_BASE_URL` xcconfig

### M7-006: RealTodoRepository
- Implements all `TodoRepository` methods using `TodoAPIClient`
- Decodes DTOs and maps to domain models
- Error mapping from `TodoAPIError` to `TodoError`

### M7-007: Wiring
- Production `AppContainer` uses `RealTodoRepository` with `TodoAPIClient`
- Base URL read from Info.plist (set via xcconfig)
- Test `AppContainer` still uses `FakeTodoRepository`
- Q-003 resolved in OPEN_QUESTIONS.md

## Previous Milestones

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
