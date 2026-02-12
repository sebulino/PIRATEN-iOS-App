# Open Questions

This document tracks unresolved questions that block implementation decisions.

**Do not guess answers.** Wait for confirmation before implementing.

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

**Status:** Open
**Blocking:** Future milestone (write features)
**Asked:** 2026-02-01

**Question:**
How should the app implement posting to forum topics and sending private messages?

**What we need:**
- Discourse endpoint for creating posts (`POST /posts`)
- Required parameters (topic_id, raw, reply_to_post_number)
- CSRF token requirements (if any)
- Draft saving behavior
- Rate limits for posting (separate from reading?)
- Markdown preview API availability

**Current implementation:**
Not implemented. M3B scope is read-only.

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

**Status:** Open
**Blocking:** M5 (Push Notifications) backend integration
**Asked:** 2026-02-08

**Question:**
What backend infrastructure is required to support push notifications for Messages and Todos?

**What we need:**

**1. Device Token Registration Endpoint**
- Endpoint to register APNs device tokens
- Required fields: device_token (hex string), user_id, platform (iOS), enabled_categories (messages, todos)
- Authentication: requires valid user session
- Response: confirmation of registration
- Deregistration endpoint for logout/opt-out

**2. Notification Sending Logic**
- Server must send push notifications via APNs when:
  - New private message received (if messages notifications enabled)
  - New/updated todo assigned (if todos notifications enabled)
- APNs endpoint: `https://api.push.apple.com/3/device/<device_token>` (production)
- APNs endpoint: `https://api.sandbox.push.apple.com/3/device/<device_token>` (development)
- Required: APNs authentication certificate or token-based auth (JWT with signing key)

**3. Notification Payload Format**
```json
{
  "aps": {
    "alert": {
      "title": "Neue Nachricht",
      "body": "Du hast eine neue Nachricht erhalten"
    },
    "badge": 1,
    "sound": "default"
  },
  "deepLink": "message",
  "topicId": 12345
}
```

**Privacy Requirements:**
- ❌ NEVER include message content in notification payload
- ❌ NEVER include sender username in payload (fetch on device after tap)
- ✅ Use generic text: "Du hast eine neue Nachricht" not "Klaus sent: Hi there"
- ✅ Only include minimal routing data: deepLink type + ID
- ✅ Respect user's enabled categories (only send if opted in)

**4. APNs Configuration**
- APNs Auth Key (.p8 file) from Apple Developer account
- Team ID and Key ID for token-based auth (recommended over certificates)
- App Bundle ID: `de.piratenpartei.PIRATEN` (must match Xcode project)
- Topics: same as bundle ID

**5. User Preferences Storage**
- Server must store per-user notification preferences
- Fields: messages_enabled (bool), todos_enabled (bool), device_token (string)
- Must support multiple devices per user (different tokens)
- Clear tokens on logout or when device unregisters

**Current implementation:**
- ✅ iOS app registers for remote notifications when permission granted
- ✅ Device token captured and stored locally
- ✅ Deep link routing implemented for message threads and todo details
- ❌ Backend registration endpoint not implemented
- ❌ APNs sending logic not implemented

**Recommendation:**
Use token-based APNs authentication (JWT) instead of certificates for easier rotation and management.

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

## Resolved Questions

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
