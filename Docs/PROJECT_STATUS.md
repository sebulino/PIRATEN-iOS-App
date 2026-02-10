# Project Status

Last updated: 2026-02-10 (M6 — Actionable Todos)

## Current Milestone

**Milestone 6: Actionable Todos (Write Operations)** — Complete

Goal: Turn Todos from a passive read-only list into an actionable participation tool with create, claim, complete, comment, and (hidden) delete capabilities.

## Milestone 6 Progress

| Story ID | Title | Status |
|----------|-------|--------|
| M6-001 | Extend Todo domain model with ownership and lifecycle fields | Complete |
| M6-002 | Create Todo UI and repository method (POST) | Complete |
| M6-003 | Claim and complete Todo actions | Complete |
| M6-004 | Todo comments (lightweight) | Complete |
| M6-005 | Todo deletion (hidden from UI) | Complete |

## Completed Work

### M6-001: Domain Model Extension
- Added `OwnerType` enum (kreisverband, landesverband, bundesverband, arbeitsgemeinschaft)
- Added `TodoStatus` enum (open, claimed, done) replacing `isCompleted: Bool`
- Added `ownerId`, `ownerName`, `assignee` fields to `Todo`
- Updated `FakeTodoRepository`, `TodosViewModel`, `TodosView` for new model

### M6-002: Create Todo
- Added `createTodo(...)` to `TodoRepository` protocol
- Created `CreateTodoViewModel` with validation (title required, length limits)
- Created `CreateTodoView` form with title, description, owner type picker, owner name
- Wired factory through `AppContainer` → `PIRATENApp` → view hierarchy
- "+" toolbar button in TodosView opens create sheet

### M6-003: Claim and Complete
- Added `claimTodo`, `completeTodo`, `unclaimTodo` to `TodoRepository`
- Created `TodoDetailView` with full info display and status-dependent actions
- Created `TodoDetailViewModel` with optimistic updates and revert on failure
- `NavigationLink` from `TodoRow` to detail view
- Deep link handling for `todoDetail` in `MainTabView`

### M6-004: Comments
- Added `TodoComment` domain model (id, todoId, authorName, text, createdAt)
- Added `fetchComments`, `addComment` to `TodoRepository`
- Comments section in `TodoDetailView` with list and text input
- Labeled as "Stub" since backend support is unknown

### M6-005: Deletion (Hidden)
- Added `deleteTodo(id:)` to `TodoRepository` protocol
- Implemented in-memory deletion in `FakeTodoRepository`
- No UI element exposes delete — repository-level only
- Rationale documented in `Docs/DECISIONS.md` (D-017)

## Previous Milestones

### Milestone 1: Bootstrap
- Clean Architecture folder structure, auth state machine, tab bar shell
- Configuration system, Keychain service, documentation

### Milestone 2: Authentication
- SSO integration via AppAuth-iOS (OIDC/OAuth2 + PKCE)
- Token storage in Keychain, session management

### Milestone 3: Forum Integration
- Discourse API client, topic listing, post viewing
- User API Key authentication for Discourse

### Milestone 4: Private Messages
- Message threads, compose flow, recipient picker
- Recent recipients, draft storage

### Milestone 5: Push Notifications
- APNs device token registration
- Deep links from notifications to Messages/Todos
- Push backend contract documentation

## Blockers

See [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) for items requiring external input.
