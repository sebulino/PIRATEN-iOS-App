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

**Status:** Open (Partially Answered)
**Blocking:** Forum/Messages features
**Asked:** 2026-01-30
**Updated:** 2026-02-01

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
- Need to investigate Options B, C, or D

**Current workaround:**
- Discourse API 401/403 errors do NOT trigger SSO session expiration
- Forum/Messages views show "not authenticated" error but user remains logged in to SSO
- See `AppContainer.swift` comment: `onAuthError: nil` for Discourse HTTP client

**Next steps:**
- Contact Discourse admin to determine which auth method is available
- Most likely Option D (User API Key) will be needed

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

**Status:** Open
**Blocking:** Todos feature
**Asked:** 2026-01-30

**Question:**
Is there an API for meine-piraten.de todo/task functionality?

**What we need:**
- API documentation or OpenAPI spec
- Authentication method
- Available endpoints
- Rate limits

**Current assumption:**
Todos view is a placeholder. No API calls implemented.

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

**Status:** Open
**Blocking:** Forum/Messages features
**Asked:** 2026-01-30

**Question:**
What is the Discourse instance URL for the forum?

**Current assumption:**
Using placeholder URL in xcconfig.

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
