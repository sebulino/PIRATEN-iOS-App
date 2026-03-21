# Open Questions

This document tracks unresolved questions that block implementation decisions.

**Do not guess answers.** Wait for confirmation before implementing.

---

## Status Overview

| ID | Question | Area | Blocks |
|----|----------|------|--------|
| [Q-001](#q-001-sso-provider-details) | SSO Provider Details | Auth | Milestone 2 |
| [Q-006](#q-006-rate-limiting-and-retry-strategy) | Rate Limiting and Retry Strategy | API | Production reliability |
| [Q-007](#q-007-piratenlogin-protocol-details) | Piratenlogin Protocol Details | Auth | Auth implementation |
| [Q-008](#q-008-token-refresh-strategy) | Token Refresh Strategy | Auth | Session management |
| [Q-009](#q-009-discourse-api-session-handling) | Discourse API Session Handling | Forum/Messages | Forum/Messages features |
| [Q-010](#q-010-token-lifetimes-and-rotation-policies) | Token Lifetimes and Rotation Policies | Auth | Documentation completeness |
| [Q-005](#q-005-user-profile-data-source) | User Profile Data Source | Profile | Profile feature |
| [Q-012](#q-012-pagination-strategy) | Pagination Strategy | Forum/Messages | Large topic/message lists |
| [Q-013](#q-013-search-functionality) | Search Functionality | Forum | Future milestone |
| ~~[Q-014](#q-014-push-notification-backend-infrastructure)~~ | ~~Push Notification Backend Infrastructure~~ | ~~Notifications~~ | ~~Resolved~~ |
| [Q-015](#q-015-push-notification-privacy-and-content-policy) | Push Notification Privacy and Content Policy | Notifications | Backend implementation |
| [Q-016](#q-016-knowledge-progress-sync-across-devices) | Knowledge Progress Sync Across Devices | Knowledge | Multi-device experience |
| [Q-017](#q-017-knowledge-content-preloading-strategy) | Knowledge Content Preloading Strategy | Knowledge | Offline experience |
| [Q-018](#q-018-offline-content-bundle-for-knowledge-hub) | Offline Content Bundle for Knowledge Hub | Knowledge | First-launch experience |
| [Q-020](#q-020-does-piragitratorde-use-rrule-recurrence-rules) | Does piragitator.de use RRULE? | Calendar | Recurring events display |
| [Q-021](#q-021-is-1-a-fixed-feed-id-on-piragitratorde) | Is `/1/` a Fixed Feed ID on piragitator.de? | Calendar | Feed configurability |

**Resolved:** Q-002, Q-003, Q-004, Q-011, Q-014, Q-019

---

## Authentication

### Q-001: SSO Provider Details

**Status:** Open
**Blocking:** Milestone 2 (Authentication)
**Asked:** 2026-01-30

**Question:**
What SSO system does the Piratenpartei use?
- OAuth2 / OIDC?
- SAML?
- Custom solution?

**What we need:**
- Authorization endpoint URL
- Token endpoint URL
- Client ID
- Required scopes
- Token format (JWT, opaque?)

**Current assumption:**
Assuming OAuth2/OIDC. Auth UI is stubbed with a fake login toggle.

---

### Q-002: Discourse Auth Strategy

**Status:** Resolved ✅
**Blocking:** Forum/Messages features
**Asked:** 2026-01-30
**Resolved:** 2026-02-02

**Question:**
How does the app authenticate to Discourse?
- **Option A: Bearer token passthrough** - Use the same access token from Piratenlogin SSO directly with Discourse API
- **Option B: DiscourseConnect (legacy SSO)** - Discourse's proprietary SSO protocol with HMAC signatures
- **Option C: Separate OAuth2 app** - Discourse configured as its own OAuth2 provider
- **Option D: User API key** - Per-user API keys generated via Discourse user settings

**What we need:**
- Confirmation of which auth method Discourse is configured for
- Whether Discourse trusts the same Keycloak issuer as the app
- Required headers/tokens for API requests
- API base URL

**CONFIRMED (2026-02-01):**
- ❌ **Option A (Bearer passthrough) does NOT work** - Discourse returns 401 when presented with the Keycloak SSO access token
- This means Discourse is NOT configured to trust the same Keycloak realm

**TESTED (2026-02-02):**
- ❌ **Option D (User API Key) returned "Oops" error** - Cause: redirect URL not in allowed list
- ✅ **Redirect URL fixed (2026-02-02)** - Changed to `piratenapp://discourse_auth`
- Discourse has allowed redirect: `piratenapp://discourse_auth`
- Discourse has these allowed scopes: read, write, message_bus, push, notifications, session_info, one_time_password
- The Discourse instance uses Piratenlogin SSO (Keycloak) for browser-based login

**Current implementation:**
- App config updated: `DISCOURSE_AUTH_REDIRECT_SCHEME=piratenapp`, `DISCOURSE_AUTH_REDIRECT_HOST=discourse_auth`
- `piratenapp` URL scheme registered in Info.plist
- Full auth flow implemented via `DiscourseAuthCoordinator` → `DiscourseAuthManager` → `ASWebAuthenticationSession`
- `DiscourseHTTPClient` uses `User-Api-Key` header for authenticated requests

**Result (2026-02-02):**
- ✅ Auth flow tested and working on simulator
- ✅ Payload decryption verified (256 bytes → JSON with key, nonce, push, api)
- ✅ Credential stored in Keychain
- ✅ User API Key: `User-Api-Key` header used for authenticated requests

**Implementation notes:**
- PKCS#1 → SPKI conversion required for RSA public key (iOS exports PKCS#1, Discourse expects SPKI)
- Base64 payload contains newlines from URL encoding - use `.ignoreUnknownCharacters` option
- URL encoding must use strict RFC 3986 (encode `+`, `/`, `=` in base64)

---

### Q-009: Discourse API Session Handling

**Status:** Open
**Blocking:** Forum/Messages features
**Asked:** 2026-01-31

**Question:**
How should the app maintain sessions with Discourse API?

**What we need:**
- Does Discourse require session cookies in addition to/instead of bearer tokens?
- Are there CSRF token requirements for write operations?
- Is there a rate limit specific to authenticated API users?
- Does Discourse return a `current_user` endpoint for session validation?

**Current assumption:**
Standard REST API with Bearer token authentication assumed until confirmed.

---

## External APIs

### Q-003: meine-piraten.de API

**Status:** Resolved ✅
**Blocking:** Todos feature
**Asked:** 2026-01-30
**Resolved:** 2026-02-10

**Question:**
Is there an API for meine-piraten.de todo/task functionality?

**Answer:**
The meine-piraten.de server is a Rails 8 app with a standard REST API (JSON via jbuilder).
- **Resources:** Tasks, Entities, Categories, Comments (nested under tasks)
- **Authentication:** None currently
- **Database:** SQLite3
- **API docs:** See `meine-piraten-server/docs/API_OVERVIEW.md`
- **Task fields:** title, description, status (open/claimed/done), assignee, entity_id, category_id, urgent, activity_points, time_needed_in_hours, creator_name, due_date
- **Comments:** Nested under tasks (GET/POST/DELETE)

**Implementation (M7):**
- iOS domain model aligned to server schema (M7-004)
- DTOs + TodoAPIClient created (M7-005)
- RealTodoRepository wired in AppContainer (M7-007)
- Base URL configurable via `MEINE_PIRATEN_BASE_URL` in xcconfig

---

### Q-006: Rate Limiting and Retry Strategy

**Status:** Open
**Blocking:** Production reliability
**Asked:** 2026-01-30
**Updated:** 2026-02-01

**Question:**
What rate limits apply and how should the app handle rate limit exhaustion?

**Known information (Discourse defaults):**
- Authenticated users: 20 requests/minute, 2,880 requests/day
- Rate limit response: HTTP 429 with `Retry-After` header

**What we still need:**
- Confirmation of actual Discourse rate limits (may differ from defaults)
- Whether meine-piraten.de has rate limits
- Preferred backoff strategy: exponential vs linear vs fixed
- Whether to show user feedback during rate limit cooldown

**Current implementation:**
- DiscourseError.rateLimited case exists
- isRetryable property returns true for rate limiting
- **No automatic retry implemented** - errors are surfaced to UI

**Recommended approach (pending confirmation):**
- Exponential backoff with max 3 retries
- Respect `Retry-After` header if present
- Show "Zu viele Anfragen - bitte kurz warten" message

---

### Q-007: Piratenlogin Protocol Details

**Status:** Open
**Blocking:** Authentication implementation
**Asked:** 2026-01-30

**Question:**
What is the exact protocol implementation of Piratenlogin?

**What we need:**
- OAuth2 vs OIDC confirmation
- Authorization server discovery document URL (if OIDC)
- Supported grant types (authorization code, PKCE required?)
- Token endpoint authentication method (client_secret_post, client_secret_basic, none?)
- Supported response types
- PKCE requirement (plain vs S256)
- Refresh token availability and rotation policy
- Token lifetimes (access token, refresh token, ID token)
- Custom claims in ID token (if OIDC)
- Logout/revocation endpoint availability

**Current assumption:**
OAuth2/OIDC with PKCE assumed per mobile best practices. Using `ASWebAuthenticationSession` for system browser flow.

---

### Q-008: Token Refresh Strategy

**Status:** Open → Partially Implemented
**Blocking:** Session management
**Asked:** 2026-01-30
**Updated:** 2026-01-31

**Question:**
How should the app handle token refresh and session continuity?

**What we implemented:**
- ✅ Refresh token is obtained via `offline_access` scope
- ✅ Token refresh uses AppAuth's OIDAuthorizationService.perform() with grant_type=refresh_token
- ✅ Access token expiration is tracked and refresh triggered at 60-second threshold
- ✅ Refresh failure transitions user to unauthenticated state

**Still need confirmation:**
- Access token lifetime (observed: appears to be short-lived, ~5 min?)
- Refresh token lifetime and rotation policy
- Whether Keycloak uses sliding window or fixed expiration for refresh tokens
- Maximum session duration before re-authentication is required

**Current assumption:**
Token refresh is implemented and working. Exact token lifetimes are server-configured and not yet documented.

---

### Q-010: Token Lifetimes and Rotation Policies

**Status:** Open
**Blocking:** Documentation completeness
**Asked:** 2026-01-31

**Question:**
What are the configured token lifetimes and rotation policies for Piratenlogin?

**What we need (Keycloak realm settings):**
- **Access token lifespan**: How long until access token expires?
- **Refresh token lifespan**: Maximum lifetime of refresh tokens?
- **Refresh token rotation**: Is a new refresh token issued on each refresh? (Keycloak default: yes)
- **Client session idle**: How long can the session be idle before requiring re-auth?
- **Client session max**: Maximum session length regardless of activity?
- **Offline session idle/max**: If using offline tokens, what are the limits?

**Why this matters:**
- Affects how often the app needs to refresh tokens in background
- Determines whether users need to re-authenticate after extended absence
- Impacts battery usage if background refresh is needed

**Current assumption:**
Using Keycloak defaults. App handles rotation by preserving new refresh tokens when returned.

---

### Q-004: Discourse Instance URL

**Status:** Resolved ✅
**Blocking:** Forum/Messages features
**Asked:** 2026-01-30
**Resolved:** 2026-02-02

**Question:**
What is the Discourse instance URL for the forum?

**Answer:**
The correct and only Discourse instance is:
```
https://diskussion.piratenpartei.de
```

There is no dev/staging Discourse instance. The previous placeholder URLs (`forum.dev.piratenpartei.de`, `forum.piratenpartei.de`) were incorrect.

**Config updated:** `Debug.xcconfig` and `Release.xcconfig` now use the correct URL.

---

## User Data

### Q-005: User Profile Data Source

**Status:** Open
**Blocking:** Profile feature
**Asked:** 2026-01-30

**Question:**
Where does user profile data come from?
- SSO provider claims?
- Discourse profile?
- Separate member database?

**What we need:**
- API endpoint for profile data
- Available profile fields
- Update capability (read-only vs editable)

---

### Q-011: Posting and Reply Functionality

**Status:** Resolved ✅
**Blocking:** Forum/Messages write features
**Asked:** 2026-02-01
**Resolved:** 2026-02-13

**Question:**
How should the app implement posting to forum topics and sending private messages?

**Answer:**
The Discourse API `POST /posts.json` endpoint supports both general topic replies and threaded post replies.

**Confirmed working:**
- **Endpoint:** `POST /posts.json`
- **Required parameters:**
  - `topic_id` (Int): The ID of the topic to post to
  - `raw` (String): Markdown content of the post
  - `reply_to_post_number` (Int, optional): For threading replies to specific posts
- **Authentication:** User API Key header (same as read operations)
- **No CSRF tokens required** for API key auth
- **Rate limiting:** Same limits as read operations (20 req/min, 2880 req/day)

**Implementation (2026-02-13):**
- ✅ Forum post replies implemented (general + threaded)
- ✅ PM replies implemented
- ✅ MessageSafetyService enforces rate limiting (30s cooldown, 10k char limit)
- ✅ ReplyComposerView shared between forum and PM replies
- ✅ Validation and error handling integrated

**Not implemented yet:**
- Draft saving (client-side only, no server sync)
- Markdown preview API
- Creating new topics (future milestone)

---

### Q-012: Pagination Strategy

**Status:** Open
**Blocking:** Large topic/message lists
**Asked:** 2026-02-01

**Question:**
How should the app handle pagination for long lists?

**Known information:**
- Discourse /latest.json returns first page (~30 topics by default)
- Topic posts are returned in chunks (first ~20 posts)
- Discourse uses `page` parameter or `before` cursor for pagination

**What we need:**
- Preferred pagination UX (infinite scroll vs explicit "load more")
- Whether to implement offline caching for previously loaded pages
- Memory management for very long lists

**Current implementation:**
First page only. No pagination support.

---

### Q-013: Search Functionality

**Status:** Open
**Blocking:** Future milestone (search feature)
**Asked:** 2026-02-01

**Question:**
How should forum/message search be implemented?

**Known information:**
- Discourse search endpoint: `GET /search.json?q=...`
- Returns topics, posts, users, categories

**What we need:**
- Whether to implement client-side filtering vs server search
- Debounce/throttle requirements for search-as-you-type
- Search result ranking preferences
- Private message search support

**Current implementation:**
Not implemented.

---

## Push Notifications

### Q-014: Push Notification Backend Infrastructure

**Status:** Resolved ✅
**Blocking:** M5 (Push Notifications) backend integration
**Asked:** 2026-02-08
**Resolved:** 2026-03-21

**Question:**
What backend infrastructure is required to support push notifications?

**Answer:**
The meine-piraten.de backend now provides push subscription endpoints:

- **POST** `/api/push_subscriptions` — Register/update device token and notification preferences
  - Body: `{ "token": "<hex>", "platform": "ios", "messages": true, "todos": false, "forum": true, "news": true }`
  - Authentication: Bearer token (meine-piraten.de access token)
- **DELETE** `/api/push_subscriptions/:token` — Deregister device token

**Implementation (2026-03-21):**
- ✅ `BackendPushNotificationRegistrationService` wired in `AppContainer` (replaces fake service)
- ✅ Endpoint paths confirmed and updated (`push_subscriptions` with underscores)
- ✅ iOS app registers for remote notifications when permission granted
- ✅ Device token captured and stored locally
- ✅ Deep link routing implemented for message threads and todo details

**Remaining backend work (not iOS app responsibility):**
- APNs sending logic (requires .p8 key from Apple Developer account)
- Token-based APNs authentication (JWT) recommended over certificates
- Discourse notification delivery handled by iOS polling (every 3 hours), not server-side webhooks

---

### Q-015: Push Notification Privacy and Content Policy

**Status:** Open
**Blocking:** Backend implementation
**Asked:** 2026-02-08

**Question:**
What content is allowed in push notification payloads to maintain privacy?

**Privacy Policy (MANDATORY):**

**Allowed in payload:**
- Generic alert text (no user names, no message content)
- Badge count (unread messages total)
- Sound identifier
- Deep link routing data (type + ID only)

**Prohibited in payload:**
- ❌ Message content or preview
- ❌ Sender username or display name
- ❌ Recipient list
- ❌ Subject line or title of message
- ❌ Any PII beyond absolute minimum for routing

**Rationale:**
- APNs payloads transit through Apple's servers (not E2E encrypted)
- Notification banners may appear on lock screen
- Notification history stored on device until dismissed
- Risk of shoulder surfing or unauthorized device access

**Implementation requirement:**
All notification text must be generic and fetch actual content after app opens via deep link.

**Example compliant payloads:**

Message notification:
```json
{
  "aps": {
    "alert": {
      "title": "PIRATEN App",
      "body": "Du hast eine neue Nachricht"
    },
    "badge": 3,
    "sound": "default"
  },
  "deepLink": "message",
  "topicId": 12345
}
```

Todo notification:
```json
{
  "aps": {
    "alert": {
      "title": "PIRATEN App",
      "body": "Ein ToDo wurde aktualisiert"
    },
    "badge": 1,
    "sound": "default"
  },
  "deepLink": "todo",
  "todoId": "abc-123"
}
```

---

## Knowledge Hub

### Q-016: Knowledge Progress Sync Across Devices

**Status:** Open
**Blocking:** Multi-device experience
**Asked:** 2026-02-12

**Question:**
Should reading progress (checklist completions, quiz results, read status) sync across devices?

**What we need:**
- Whether users expect progress to follow them to a new device
- Server-side storage endpoint for progress data
- Conflict resolution strategy (last-write-wins vs merge)

**Current implementation:**
Progress stored locally in UserDefaults. Lost on app reinstall or device change.

---

### Q-017: Knowledge Content Preloading Strategy

**Status:** Open
**Blocking:** Offline experience improvement
**Asked:** 2026-02-12

**Question:**
Should the app preload all knowledge content on first launch or continue with on-demand loading?

**Considerations:**
- Current approach: Index fetched on Knowledge tab open, topic content fetched on topic open
- Preloading all content would enable full offline access (~50–100 markdown files)
- Trade-off: initial download time vs. offline availability
- GitHub API rate limits (60/hour unauthenticated) may constrain bulk fetching

**Current implementation:**
On-demand loading with file cache. Cached content available offline after first fetch.

---

### Q-018: Offline Content Bundle for Knowledge Hub

**Status:** Open
**Blocking:** First-launch experience
**Asked:** 2026-02-12

**Question:**
Should a baseline knowledge content bundle be shipped with the app binary?

**Considerations:**
- First launch currently requires network to see any content
- Bundling a snapshot of PIRATEN-Kanon ensures content is available immediately
- Adds to app binary size
- Bundled content may become stale if not updated

**Current implementation:**
No bundled content. Empty state shown until first successful fetch.

---

## piragitator.de Calendar

### Q-020: Does piragitator.de use RRULE (Recurrence Rules)?

**Status:** Open
**Blocking:** Accurate display of recurring events
**Asked:** 2026-02-19

**Question:**
Does the piragitator.de iCal feed use RRULE properties for recurring events?

**What we need:**
- Confirmation whether events use RRULE, RDATE, or EXDATE
- If so, which recurrence patterns are used (DAILY, WEEKLY, MONTHLY?)

**Current assumption:**
The custom ICalParser does not support RRULE. If the feed uses recurrence rules, recurring events will only show their first occurrence. The parser would need to be extended to expand recurrences.

---

### Q-021: Is `/1/` a Fixed Feed ID on piragitator.de?

**Status:** Open
**Blocking:** Future calendar feed configurability
**Asked:** 2026-02-19

**Question:**
The calendar endpoint `/api/veranstaltung/ical/1/` uses `/1/` as a path parameter. Is this a fixed feed ID, or could it change? Are there other feed IDs for different event categories?

**Current assumption:**
`/1/` is treated as a constant in `CalendarAPIClient`. If multiple feeds exist, the endpoint path would need to become configurable.

---

## Resolved Questions

### Q-019: Create PIRATEN-Kanon GitHub Repository

**Status:** Resolved
**Asked:** 2026-02-12
**Resolved:** 2026-02-12

**Answer:** Repository was private, now switched to public. AppContainer uses `RealKnowledgeRepository` pointing at `sebulino/PIRATEN-Kanon`.

(Move questions here once answered)

---

## How to Add a Question

1. Create a new entry with unique ID (Q-XXX)
2. Set status to "Open"
3. Note what feature/milestone it blocks
4. Describe what information is needed
5. State current assumption (if any)

When answered:
1. Update status to "Resolved"
2. Add answer and date
3. Move to "Resolved Questions" section
