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

**Question:**
How does the app authenticate to Discourse?
- Same SSO as member login?
- Discourse SSO (DiscourseConnect)?
- API key per user?
- Separate OAuth app?

**What we need:**
- Auth flow documentation
- Required credentials/tokens
- API base URL

**Current assumption:**
Forum features are UI stubs only.

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

**Status:** Open
**Blocking:** Session management
**Asked:** 2026-01-30

**Question:**
How should the app handle token refresh and session continuity?

**What we need:**
- Refresh token availability confirmation
- Token refresh endpoint and method
- Sliding session vs fixed expiration
- Background refresh capability requirements
- Offline access token scope availability
- Grace period for expired tokens

**Current assumption:**
Refresh tokens assumed available. App will attempt silent refresh before session expiration. No offline access until confirmed.

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
