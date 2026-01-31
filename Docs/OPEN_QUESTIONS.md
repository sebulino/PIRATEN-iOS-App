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

**Status:** Open
**Blocking:** Forum/Messages features
**Asked:** 2026-01-30
**Updated:** 2026-01-31

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

**Technical Context:**
The app now has working OAuth2/OIDC with Piratenlogin. Access tokens include:
- `sub` claim (user identifier)
- `profile` scope claims (name, preferred_username)

If Discourse trusts the same Keycloak realm, Option A (bearer passthrough) would be simplest.

**Current assumption:**
Forum features are UI stubs only. AuthenticatedHTTPClient is ready to inject Bearer tokens once Discourse integration is confirmed.

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

### Q-006: Rate Limiting and Permissions

**Status:** Open
**Blocking:** All external integrations
**Asked:** 2026-01-30

**Question:**
What rate limits and permission models apply to external APIs?

**What we need for each service (Discourse, meine-piraten.de):**
- Rate limit thresholds (requests per minute/hour)
- Rate limit response headers or error codes
- Permission model (role-based? group-based?)
- Required scopes or permissions for app access
- Handling of rate limit exhaustion (retry strategies)

**Current assumption:**
No rate limiting implemented. Fake repositories have simulated delays only.

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
