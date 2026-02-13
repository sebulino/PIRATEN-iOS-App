# PRD: M5 - Create New Private Message Threads

## Introduction

Enable users to start new private message conversations by searching for recipients and composing messages. This completes the messaging feature set by adding write capability for new threads (M4 added reply to existing threads).

Currently, users can view PM threads and reply to existing conversations, but cannot initiate new ones. This milestone adds the ability to compose and send new private messages to other Discourse users.

## Goals

- Allow users to create new private message threads with a single recipient (MVP)
- Provide intuitive recipient discovery via recent contacts and search
- Require subject line per Discourse conventions
- Auto-save drafts to prevent message loss
- Maintain privacy-first principles (no logging of message content)
- Reuse existing safety rails from M4 (rate limiting, input validation)

## User Stories

### M5-001: User Search API Integration
**Description:** As a user, I want to search for other users so I can find the person I want to message.

**Acceptance Criteria:**
- [ ] DiscourseAPIClient exposes `searchUsers(query:)` method using `GET /u/search/users.json`
- [ ] Search returns username, display name, and avatar URL
- [ ] Empty query returns empty results (no random users)
- [ ] Minimum 2 characters required before search executes
- [ ] Errors map to domain errors with user-friendly messages
- [ ] Context7 consulted for Discourse user search API; summary added to progress.txt

### M5-002: Recent Recipients Storage
**Description:** As a user, I want to see people I've recently messaged so I can quickly start new conversations with them.

**Acceptance Criteria:**
- [ ] Store up to 10 recent recipient usernames locally (UserDefaults, not Keychain)
- [ ] Recent recipients updated when sending a new PM
- [ ] Recent recipients list persists across app restarts
- [ ] No PII beyond username stored; privacy-safe implementation
- [ ] Clear recent recipients when user logs out

### M5-003: Recipient Picker UI
**Description:** As a user, I want to select a message recipient from recent contacts or search results.

**Acceptance Criteria:**
- [ ] Screen shows "Recent" section with up to 5 recent recipients
- [ ] Search field at top with placeholder "Benutzer suchen..."
- [ ] Search results appear below as user types (debounced 300ms)
- [ ] Each row shows avatar placeholder/initials, display name, @username
- [ ] Tapping a user selects them and proceeds to compose screen
- [ ] Cancel button returns to Messages tab
- [ ] Context7 consulted for SwiftUI search/picker patterns; summary added to progress.txt

### M5-004: New Message Compose UI
**Description:** As a user, I want to compose a new message with subject and body.

**Acceptance Criteria:**
- [ ] Shows selected recipient at top (avatar + name, tap to change)
- [ ] Required subject field with "Betreff" placeholder
- [ ] Message body field reuses M4 composer patterns
- [ ] Send button disabled until subject and body are non-empty
- [ ] Character count shown for body (reuse M4 safety service)
- [ ] Cancel button with confirmation if content exists
- [ ] Keyboard handling matches M4 composer

### M5-005: Create PM API Integration
**Description:** As a developer, I need to send the new PM to Discourse so the conversation is created.

**Acceptance Criteria:**
- [ ] DiscourseAPIClient exposes `createPrivateMessage(recipient:title:content:)` method
- [ ] Uses `POST /posts.json` with `archetype: private_message`, `target_recipients`, `title`, `raw`
- [ ] Success navigates to the new thread detail view
- [ ] Errors display user-friendly messages (recipient not found, rate limited, etc.)
- [ ] Reuses M4 safety service for rate limiting and validation
- [ ] Context7 consulted for Discourse create PM endpoint; summary added to progress.txt

### M5-006: Draft Auto-Save
**Description:** As a user, I want my in-progress message saved automatically so I don't lose work if I leave the app.

**Acceptance Criteria:**
- [ ] Draft saved to local storage when compose screen disappears
- [ ] Draft includes: recipient username, subject, body, timestamp
- [ ] Draft restored when returning to compose screen (prompt to restore or discard)
- [ ] Draft cleared after successful send
- [ ] Only one draft stored at a time (new draft overwrites old)
- [ ] Draft storage uses Codable + UserDefaults (not Keychain)

### M5-007: New Message Entry Point
**Description:** As a user, I want an obvious way to start a new message from the Messages tab.

**Acceptance Criteria:**
- [ ] Floating action button (FAB) in bottom-right of Messages tab
- [ ] FAB uses system "square.and.pencil" icon with orange tint
- [ ] FAB only visible when authenticated (hides in not-authenticated state)
- [ ] Tapping FAB opens recipient picker (M5-003)
- [ ] FAB positioned above tab bar with proper safe area handling

## Functional Requirements

- FR-1: User search via `GET /u/search/users.json?term={query}` with 2+ character minimum
- FR-2: Create PM via `POST /posts.json` with `archetype=private_message`, `target_recipients`, `title`, `raw`
- FR-3: Store recent recipients in UserDefaults (max 10, username only)
- FR-4: Auto-save single draft to UserDefaults with recipient, subject, body, timestamp
- FR-5: FAB button on Messages tab for authenticated users only
- FR-6: Subject line is required, body uses existing M4 validation (max 10,000 chars)
- FR-7: Rate limiting reuses MessageSafetyService from M4
- FR-8: Clear recent recipients and draft on logout

## Non-Goals (Out of Scope)

- Multiple recipients (group PMs) - future milestone
- Attachments/image upload - future milestone
- Markdown preview - future milestone
- Rich text editing - not planned
- Contact/address book integration - not planned
- Server-side draft sync - not planned

## Design Considerations

- Reuse `MessagePostRow` avatar styling from M4-004 for consistency
- Reuse `ReplyComposerView` patterns for the compose body
- FAB should use SwiftUI overlay with animation
- Recipient picker should feel native (similar to iOS Messages app)
- German localization for all user-facing strings

## Technical Considerations

- User search API returns partial matches; handle gracefully
- Discourse requires `target_recipients` as comma-separated usernames
- New PM returns created topic; use topic_id to navigate to detail view
- Draft storage should be lightweight (UserDefaults, not Core Data)
- Recent recipients list is per-device, not synced

## Success Metrics

- User can create and send a new PM in under 30 seconds
- Draft recovery prevents message loss on app backgrounding
- Recent recipients reduce time to find frequent contacts
- No increase in error rates compared to M4 reply functionality

## Open Questions

- Q-014: Should we show user online/offline status in search results? (Discourse may not expose this)
- Q-015: What happens if recipient has disabled PMs? (Need to test error response)
- Q-016: Should FAB hide when scrolling the messages list? (UX preference)

## Dependencies

- M4 complete (reply functionality, safety service, composer patterns)
- Discourse auth working (User API Key with write scope)
