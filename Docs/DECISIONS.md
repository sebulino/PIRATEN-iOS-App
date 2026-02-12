# Architectural Decisions

This document records significant architectural decisions and their rationale.

---

## D-001: Clean Architecture + MVVM

**Date:** 2026-01-30
**Status:** Accepted

### Context
The app needs a maintainable architecture that supports:
- Multiple feature modules (Forum, Messages, etc.)
- Testability without network dependencies
- Clear separation between UI and business logic

### Decision
Adopt Clean Architecture with MVVM for the presentation layer:
- **Presentation**: SwiftUI Views + ViewModels
- **Domain**: Entities, Use Cases, Repository protocols
- **Data**: API clients, DTOs, Repository implementations
- **Support**: System wrappers (Keychain, Config)

### Rationale
- Clean Architecture enforces dependency inversion (domain doesn't know about data layer)
- MVVM fits naturally with SwiftUI's reactive model
- Repository protocols enable stubbing external services
- Well-understood patterns reduce onboarding time

---

## D-002: Native Keychain for Token Storage

**Date:** 2026-01-30
**Status:** Accepted

### Context
Authentication tokens need secure storage. Options:
1. UserDefaults (insecure)
2. File with encryption (complex)
3. iOS Keychain (system-provided secure storage)
4. Third-party library (external dependency)

### Decision
Use native iOS Keychain via Security framework.

### Rationale
- Keychain is the iOS-sanctioned secure storage
- No third-party dependencies to audit
- Hardware-backed encryption on modern devices
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` prevents backup extraction

---

## D-003: xcconfig for Configuration

**Date:** 2026-01-30
**Status:** Accepted

### Context
The app needs environment-specific configuration (URLs, keys) without hardcoding secrets.

### Decision
Use `.xcconfig` files:
- `Debug.xcconfig` - development settings
- `Release.xcconfig` - production settings
- `Secrets.xcconfig` - local secrets (git-ignored)
- `Secrets.sample.xcconfig` - template for secrets

### Rationale
- Native Xcode solution, no build script complexity
- Secrets file is git-ignored, preventing accidental commits
- Sample file documents required keys
- Build configurations can include different xcconfig files

---

## D-004: Protocol-First External Services

**Date:** 2026-01-30
**Status:** Accepted

### Context
External APIs (SSO, Discourse, meine-piraten.de) are not yet fully documented. Implementation cannot block on API availability.

### Decision
Define protocols for all external services first:
- `AuthServiceProtocol`
- `ForumRepositoryProtocol`
- `TodoRepositoryProtocol`

Implementations can be stubbed until APIs are confirmed.

### Rationale
- Development can proceed without real backends
- Tests can use mock implementations
- Real implementations plug in without changing consumers
- Avoids guessing API details incorrectly

---

## D-005: No Analytics or Tracking

**Date:** 2026-01-30
**Status:** Accepted

### Context
The app is for Piratenpartei members. Privacy is a core party value.

### Decision
No analytics, tracking, or telemetry will be implemented.

### Rationale
- Aligns with party values
- Reduces legal compliance burden (GDPR)
- Simplifies architecture (no analytics SDK)
- User trust is paramount

---

## D-006: SwiftUI-Only UI

**Date:** 2026-01-30
**Status:** Accepted

### Context
iOS 18+ deployment target allows full SwiftUI adoption.

### Decision
Use SwiftUI exclusively. No UIKit except where required for system integration (e.g., `ASWebAuthenticationSession`).

### Rationale
- Modern, declarative UI framework
- Simpler view code
- Built-in state management with Combine
- iOS 18+ gives access to all modern SwiftUI features

---

## D-007: Pinned Simulator Destination for Automation

**Date:** 2026-01-30
**Status:** Accepted

### Context
Automated xcodebuild runs using `-destination 'platform=iOS Simulator,name=iPhone 16'` can create simulator clones when multiple simulators share the same name. This leads to:
- Wasted disk space from clone accumulation
- Ambiguous test environments
- Potential CI/CD failures when name resolution picks the wrong simulator

### Decision
Pin a specific simulator UDID for all automated builds and tests:

**Primary Destination (iOS 26.2):**
```
-destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041'
```

This targets: iPhone 16 running iOS 26.2

### Rationale
- UDID-based destinations are unambiguous and prevent clone creation
- iOS 26.2 is the latest available runtime in the current Xcode version
- Using a specific device UDID ensures consistent test environments
- If the UDID becomes unavailable (e.g., after Xcode update), the build will fail explicitly rather than silently using a different simulator

### Fallback
If the pinned simulator is unavailable after an Xcode update:
1. Run `xcrun simctl list devices available` to list available simulators
2. Select an iPhone 16 (or similar) UDID from the iOS 18.x runtime
3. Update this document and CLAUDE.md with the new UDID

---

## D-008: Local-Only Logout (No end_session_endpoint Call)

**Date:** 2026-01-31
**Status:** Accepted

### Context
The OIDC discovery document from the Keycloak issuer provides an `end_session_endpoint`. This endpoint can be used to terminate the server-side session in addition to clearing local tokens. The question is whether to use it.

Options:
1. **Local-only logout**: Clear tokens from Keychain only
2. **RP-Initiated logout**: Also call `end_session_endpoint` with `id_token_hint`

### Decision
Use **local-only logout** for now. Do not call `end_session_endpoint`.

### Rationale
1. **Simplicity**: Local logout is sufficient for mobile apps - the refresh token will naturally expire
2. **Reliability**: The end_session_endpoint requires opening a browser window, which may be confusing for users ("why does the browser open when I logout?")
3. **No SSO with other apps**: We are the only Piratenpartei mobile app using this SSO - there are no other RPs that would benefit from server-side session termination
4. **Privacy**: Calling the endpoint requires redirecting through a browser, potentially exposing the logout action to browser extensions/history
5. **Offline support**: Local logout works even when offline; server logout would fail

### When to revisit
Consider implementing RP-Initiated logout if:
- Other Piratenpartei apps share the same SSO and need coordinated logout
- Security requirements mandate immediate server-side token revocation
- A token revocation endpoint (RFC 7009) becomes available (preferred over end_session)

### References
- [OpenID Connect RP-Initiated Logout 1.0](https://openid.net/specs/openid-connect-rpinitiated-1_0.html)
- The `endSessionEndpoint` is discovered and stored in `OIDCConfiguration` but not currently used

---

## D-009: AppAuth-iOS for OAuth2/OIDC Implementation

**Date:** 2026-01-31
**Status:** Accepted

### Context
The app needs to authenticate users via the Piratenpartei SSO (Keycloak). We needed to choose an OAuth2/OIDC implementation approach.

Options considered:
1. **Manual implementation** using URLSession and ASWebAuthenticationSession
2. **AppAuth-iOS** (OpenID Foundation reference implementation)
3. **Third-party alternatives** (Auth0 SDK, Firebase Auth, etc.)

### Decision
Use **AppAuth-iOS** (https://github.com/openid/AppAuth-iOS) via Swift Package Manager.

### Rationale
1. **RFC 8252 Compliance**: AppAuth is specifically designed to implement OAuth 2.0 for Native Apps (RFC 8252) best practices
2. **PKCE Built-in**: Automatically generates code_challenge/code_verifier for PKCE (RFC 7636), which is mandatory for native apps
3. **OpenID Foundation Reference**: Official reference implementation, well-maintained and audited
4. **ASWebAuthenticationSession Integration**: Uses the system browser automatically on iOS 12+, preventing embedded webview security issues
5. **Discovery Support**: Handles OIDC discovery (/.well-known/openid-configuration) automatically
6. **No Vendor Lock-in**: Works with any standards-compliant OIDC provider (Keycloak, Okta, Auth0, etc.)

### References
- [RFC 8252 - OAuth 2.0 for Native Apps](https://www.rfc-editor.org/rfc/rfc8252.html)
- [RFC 7636 - Proof Key for Code Exchange (PKCE)](https://www.rfc-editor.org/rfc/rfc7636)
- [AppAuth-iOS Repository](https://github.com/openid/AppAuth-iOS)

---

## D-010: OAuth2/OIDC Configuration for Piratenlogin

**Date:** 2026-01-31
**Status:** Accepted

### Context
Document the exact OAuth2/OIDC configuration used for Piratenlogin SSO authentication.

### Configuration

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Issuer** | `https://sso.piratenpartei.de/realms/Piratenlogin` | Keycloak realm URL |
| **Client ID** | `piraten_ios_app` | Public client (no secret) |
| **Redirect URI** | `de.meine-piraten://oauth-callback` | Custom URL scheme |
| **Scopes** | `openid profile offline_access` | Standard OIDC scopes |
| **Grant Type** | Authorization Code + PKCE | RFC 8252 recommended |
| **Token Endpoint Auth** | None (public client) | Native apps don't use client secrets |

### OIDC Discovery

Endpoints are NOT hardcoded. They are fetched dynamically from:
```
https://sso.piratenpartei.de/realms/Piratenlogin/.well-known/openid-configuration
```

The discovery document provides:
- `authorization_endpoint` - For authorization code request
- `token_endpoint` - For token exchange
- `userinfo_endpoint` - For fetching user claims
- `end_session_endpoint` - For RP-initiated logout (currently unused, see D-008)
- `jwks_uri` - For token signature verification
- `issuer` - For token validation

### Scopes Explained

| Scope | Purpose |
|-------|---------|
| `openid` | Required for OIDC; returns ID token with `sub` claim |
| `profile` | Returns user profile claims (name, preferred_username, etc.) |
| `offline_access` | Returns refresh token for session renewal |

### Security Notes
- **No client secret**: Native apps are public clients per RFC 8252; PKCE provides authorization code protection instead
- **Private-use URI scheme**: `de.meine-piraten://` is registered in Info.plist; potential for scheme hijacking is mitigated by PKCE
- **Tokens in Keychain only**: Never stored in UserDefaults or logged

---

## D-011: Single-Attempt Auth Error Handling (No Retry Loops)

**Date:** 2026-02-01
**Status:** Accepted

### Context
When an API call returns 401 (Unauthorized) or 403 (Forbidden), the app needs to handle this gracefully. However, multiple API calls may be in flight simultaneously (e.g., forum topics + private messages loading). If each failed call triggers a re-auth transition, this can cause:
- Multiple logout calls
- State machine confusion
- UI flickering
- Potential infinite loops if token refresh fails repeatedly

### Decision
Implement a **single-attempt rule** for auth error handling:

1. **First 401/403 response**: Triggers logout and transitions to `.sessionExpired` state
2. **Subsequent 401/403 responses** (while handling): Ignored via guard flag
3. **Guard flag reset**: Occurs only on successful re-authentication or explicit logout

### Implementation
- `AuthStateManager.isHandlingAuthError` flag guards concurrent error handling
- `AuthStateManager.handleAuthenticationError()` checks the flag before processing
- New `AuthState.sessionExpired` case provides clear UI messaging
- No automatic retry of token refresh - user must explicitly re-authenticate

### Rationale
1. **No infinite loops**: Single-attempt prevents cascading failures
2. **Clear UX**: User sees one "session expired" message, not multiple error popups
3. **Predictable behavior**: State transitions are deterministic
4. **Follows Context7 best practices**: Similar to Angular OAuth2 OIDC patterns

### UI Flow
```
401/403 received
    → handleAuthenticationError() called (if not already handling)
    → isHandlingAuthError = true
    → logout() clears credentials
    → state = .sessionExpired
    → UI shows SessionExpiredView
    → User taps "Erneut anmelden"
    → authenticate() called
    → On success: isHandlingAuthError = false, state = .authenticated
```

### References
- Context7: angular-oauth2-oidc session change handling patterns
- Context7: retry-ts limitRetries policy for preventing infinite loops

---

## D-012: Discourse API Integration (M3B)

**Date:** 2026-02-01
**Status:** Accepted

### Context
Document the Discourse API integration for forum and private messages.

### Base URL
```
https://diskussion.piratenpartei.de
```

### Authentication Mechanism
**Bearer Token Passthrough** (assumed): The SSO access token is passed directly via `Authorization: Bearer <token>` header. This assumes Discourse trusts the same Keycloak realm.

If this doesn't work, fallback to User-API-Key authentication would be needed (see OPEN_QUESTIONS.md Q-002).

### Endpoints Used

| Feature | Endpoint | Method | Notes |
|---------|----------|--------|-------|
| Latest topics | `/latest.json` | GET | Returns topic list with users |
| Topic detail | `/t/{topic_id}.json` | GET | Returns topic with posts |
| Private messages | `/topics/private-messages/{username}.json` | GET | Returns PM inbox |
| PM thread | `/t/{topic_id}.json` | GET | Same as topic detail; PMs are topics with archetype='private_message' |

### Response Handling
- All responses are JSON
- Error responses follow Discourse format: `{ "errors": [...], "error_type": "..." }`
- 429 responses indicate rate limiting (default: 20 req/min for authenticated users)

### What Is NOT Implemented (M3B Scope)
- Posting/replying to topics or messages
- Real-time notifications
- Search functionality
- Pagination (currently fetches first page only)
- Rate limit backoff/retry

---

## D-013: Brand Asset Management (SVG + PDF Workflow)

**Date:** 2026-02-01
**Status:** Accepted

### Context
The app needs to include official Piratenpartei brand assets (logos, emblems). iOS has limited native SVG support in asset catalogs, requiring a conversion strategy.

### Decision
Store brand assets as SVG in `PIRATEN/Resources/Brand/` for version control and source-of-truth purposes. Convert to PDF for integration into `Assets.xcassets` when needed in the UI.

### File Structure
```
PIRATEN/Resources/
├── Brand/
│   ├── README.md          # Usage documentation
│   └── PiratenSignet.svg  # Official logo (source)
└── Assets.xcassets/
    └── (PDF versions for app use)
```

### Rationale
1. **SVG for source control**: Vector format, text-diffable, easy to maintain
2. **PDF for Xcode**: Native support in asset catalogs, "Preserve Vector Data" feature
3. **Separation of concerns**: Source assets vs. compiled assets
4. **No runtime dependencies**: Avoids need for SVG rendering libraries

### Workflow
When a logo is needed in the app:
1. Convert SVG to PDF (using design tools or converters)
2. Add PDF to `Assets.xcassets` with "Preserve Vector Data" enabled
3. Reference via `Image("logo-name")` in SwiftUI

### Alternative Considered
Using SwiftSVG or similar libraries for runtime SVG rendering was rejected due to:
- Added dependency overhead
- Unnecessary complexity for static assets
- No dynamic SVG requirements identified

---

## D-014: Discourse User API Key Authentication

**Date:** 2026-02-02
**Status:** Accepted

### Context
Discourse does not accept SSO Bearer tokens directly for API authentication (see Q-002 in OPEN_QUESTIONS.md). An alternative authentication mechanism is needed.

### Decision
Implement Discourse User API Key authentication flow following the official specification:

**Flow:**
1. Generate RSA key pair (2048-bit), store private key in Keychain
2. Build auth URL with client_id, nonce, redirect scheme, scopes, and public key PEM
3. Open URL via ASWebAuthenticationSession (user authenticates via browser)
4. Receive callback with RSA-encrypted payload
5. Decrypt payload using stored private key
6. Verify nonce matches original request
7. Store API key + client ID in Keychain
8. Use `User-Api-Key` and `User-Api-Client-Id` headers for all Discourse requests

**Key Files:**
- `RSAKeyManager.swift` - RSA key pair generation/storage/decryption
- `DiscourseAuthManager.swift` - Auth flow orchestration
- `DiscourseCredential.swift` / `DiscourseAuthResponse.swift` - Domain models
- `DiscourseAPIKeyProvider.swift` - Protocol for credential access
- `DiscourseHTTPClient.swift` - HTTP client wrapper that injects auth headers

### Rationale
1. **Official API**: User API Keys are the recommended Discourse mobile auth method
2. **Secure**: RSA encryption protects the key in transit; Keychain protects at rest
3. **Independent of SSO**: Works regardless of how user authenticated to Discourse
4. **Revocable**: Keys can be revoked server-side or on logout
5. **Scoped**: Requested scopes limit key permissions (currently: notifications, session_info)

### Configuration Required
These Info.plist keys must be set (via xcconfig):
- `DISCOURSE_BASE_URL` - Discourse instance URL (`https://diskussion.piratenpartei.de`)
- `DISCOURSE_CLIENT_ID` - Unique client identifier (`de.meine-piraten.ios-app`)
- `DISCOURSE_AUTH_REDIRECT_SCHEME` - URL scheme (`piratenapp`)
- `DISCOURSE_AUTH_REDIRECT_HOST` - Callback host (`discourse_auth`)
- `DISCOURSE_APP_NAME` - App name shown in Discourse

### Redirect URL
The app uses `piratenapp://discourse_auth` as the callback URL. This is configured as an allowed redirect in the Discourse admin panel.

### Scopes
Currently using: `read,session_info`
- `read` - Read-only access to forum content
- `session_info` - User session information

Note: `notifications` and `push` scopes require a `push_url` parameter and are not currently used.

### References
- [Discourse User API Keys Specification](https://meta.discourse.org/t/user-api-keys-specification/48536)

---

## D-015: Official Discourse Instance URL

**Date:** 2026-02-02
**Status:** Accepted

### Context
During authentication testing, the app was redirecting to `forum.dev.piratenpartei.de` which does not exist.

### Decision
The correct and only Discourse instance URL is:
```
https://diskussion.piratenpartei.de
```

This URL is used for both development and production. There is no separate dev/staging Discourse instance.

### Configuration Updated
- `Config/Debug.xcconfig` - `DISCOURSE_BASE_URL` corrected
- `Config/Release.xcconfig` - `DISCOURSE_BASE_URL` corrected

### Rationale
This is the actual production Discourse forum used by the Piratenpartei. Previous placeholder URLs (`forum.dev.piratenpartei.de`, `forum.piratenpartei.de`) were incorrect.

---

## D-016: RSA Public Key Format (PKCS#1 → SPKI Conversion)

**Date:** 2026-02-02
**Status:** Accepted

### Context
When implementing Discourse User API Key authentication, the RSA public key export failed server-side with HTTP 500. Investigation revealed:
- iOS `SecKeyCopyExternalRepresentation` exports in **PKCS#1** format
- Discourse expects **SPKI (X.509 SubjectPublicKeyInfo)** format

### Decision
Convert PKCS#1 to SPKI by prepending the ASN.1 AlgorithmIdentifier header in `RSAKeyManager.swift`.

### Implementation
SPKI wraps PKCS#1 with an AlgorithmIdentifier:
```
SEQUENCE {
    AlgorithmIdentifier { OID rsaEncryption (1.2.840.113549.1.1.1), NULL }
    BIT STRING { 0x00 (unused bits), PKCS#1 data }
}
```

The conversion adds a 15-byte ASN.1 header followed by the BIT STRING wrapper around the original PKCS#1 data.

### Additional Fix: Base64 Newlines
Discourse returns the encrypted payload with newlines (URL-encoded as `%0A`). Swift's `Data(base64Encoded:)` fails on these by default. Fixed by using:
```swift
Data(base64Encoded: payload, options: .ignoreUnknownCharacters)
```

### References
- [RFC 8017 - PKCS #1](https://www.rfc-editor.org/rfc/rfc8017)
- [RFC 5280 - SubjectPublicKeyInfo](https://www.rfc-editor.org/rfc/rfc5280#section-4.1.2.7)

---

## D-017: Todo Deletion Hidden from UI

**Date:** 2026-02-10
**Status:** Accepted

### Context
The Todo system supports create, claim, complete, and unclaim operations. Deletion is a destructive action that could lead to accidental data loss, especially in a collaborative environment where multiple members interact with shared tasks.

### Decision
Implement `deleteTodo(id:)` at the repository level but do **not** expose any UI element (button, swipe action, context menu) for deletion. The method is callable only through debug/internal paths.

### Rationale
1. **Prevent accidental data loss**: In a party organization context, deleting a todo that others may reference causes confusion
2. **Admin-only capability**: Deletion should be reserved for administrators or maintenance tasks, not regular users
3. **Soft approach**: The method exists in the protocol so real backend implementations can support it when admin tools are built
4. **Minimal risk**: Since the meine-piraten.de API is still unknown (Q-003), we avoid committing to a destructive user-facing flow that may not match the backend's model

### When to revisit
- When the meine-piraten.de API schema is confirmed and includes delete semantics
- When an admin/moderation interface is designed
- If user research indicates a need for user-initiated archiving or deletion

---

## D-018: meine-piraten.de API Integration Approach

**Date:** 2026-02-10
**Status:** Accepted

### Context
The meine-piraten.de server is a Rails 8 app with a standard REST API (JSON/jbuilder, SQLite3, no authentication). The iOS app needs to consume this API for Todo functionality.

### Decision
1. **Direct REST client** — follow the same pattern as DiscourseAPIClient: dedicated TodoAPIClient with HTTPClient injection, raw Data return, error mapping.
2. **No authentication wrapper** — the server has no auth layer. Use plain URLSessionHTTPClient (no DiscourseHTTPClient-style wrapper needed).
3. **Domain model alignment** — restructure iOS domain models to match the server schema rather than maintaining a separate abstraction. This reduces mapping complexity.
4. **Server extensions first** — add missing fields (status, assignee) and comments model to the server before building the iOS client.
5. **FakeTodoRepository preserved** — keep for tests and SwiftUI previews; production uses RealTodoRepository.

### Rationale
- Matching the server schema avoids unnecessary impedance mismatch
- No auth simplifies the client (no token injection needed)
- Following the Discourse pattern keeps the codebase consistent
- Server-first ensures the iOS client targets a stable API

### Consequences
- If the server adds authentication later, we'll need a TodoHTTPClient wrapper (similar to DiscourseHTTPClient)
- The `completed` boolean field on the server is now redundant with `status` — could be removed in a future migration

---

## D-019: GitHub API for Knowledge Content (Public Repo, No Auth)

**Date:** 2026-02-12
**Status:** Accepted

### Context
The Knowledge Hub needs to fetch educational content. The content lives in a public GitHub repository (sebulino/PIRATEN-Kanon). Options:
1. Bundle content in the app binary
2. Fetch from GitHub API at runtime
3. Self-hosted content server

### Decision
Fetch content from the public GitHub Contents API (`api.github.com/repos/{owner}/{repo}/contents/`). No authentication required for public repos.

### Rationale
1. **No infrastructure**: No server to maintain; GitHub provides reliable CDN
2. **Content versioned in Git**: Updates to the repo are immediately available to app users
3. **ETag support**: Conditional requests (If-None-Match) avoid re-downloading unchanged content
4. **Rate limits acceptable**: Unauthenticated GitHub API allows 60 requests/hour per IP, sufficient for occasional content fetches with local caching
5. **No bundling overhead**: App stays small; content loaded on demand

### Consequences
- Subject to GitHub API rate limits (60/hour unauthenticated)
- First launch requires network access to load content
- Cache mitigates rate limit concerns for normal usage

---

## D-020: File-Based Cache with 24h TTL for Knowledge Content

**Date:** 2026-02-12
**Status:** Accepted

### Context
Knowledge content should be available offline and avoid excessive API calls. Options:
1. Core Data / SQLite
2. File-based JSON cache in Caches directory
3. In-memory only

### Decision
Use file-based JSON cache in `<Caches>/Knowledge/` with 24-hour TTL. Atomic writes (temp file + rename) prevent corruption.

### Rationale
1. **Simplicity**: JSON files match the Codable models directly
2. **System-managed**: iOS can reclaim Caches directory under storage pressure
3. **Atomic writes**: Prevents partial/corrupt cache files
4. **24h TTL**: Balances freshness with API rate limits; ETag conditional requests further reduce bandwidth
5. **No schema migration**: Unlike Core Data, no migration needed when models change

---

## D-021: UserDefaults for Reading Progress

**Date:** 2026-02-12
**Status:** Accepted

### Context
Reading progress (checklist completions, quiz results, read status) needs persistence. Options:
1. Core Data
2. UserDefaults with JSON encoding
3. File-based storage

### Decision
Use UserDefaults with JSON-encoded `[String: TopicProgress]` dictionary under key `piraten_knowledge_progress`.

### Rationale
1. **Small data volume**: Progress data is lightweight (topic IDs + booleans + scores)
2. **Matches existing pattern**: `RecentRecipientsStore` uses the same approach
3. **Test-friendly**: Constructor-injected UserDefaults enables test isolation
4. **No migration complexity**: Simple JSON encoding, no schema to manage
5. **Survives cache clearing**: UserDefaults is not in Caches, so progress persists even if content cache is cleared

### When to revisit
- If progress needs to sync across devices (would need server-side storage)
- If data volume grows significantly (unlikely for reading progress)

---

## D-022: Custom YAML Frontmatter Parser (No External Dependencies)

**Date:** 2026-02-12
**Status:** Accepted

### Context
Knowledge content files use YAML frontmatter (--- delimited) for metadata. Options:
1. Full YAML parsing library (Yams)
2. Custom subset parser
3. JSON-only metadata format

### Decision
Implement a custom YAML subset parser that handles the known frontmatter fields: simple key-value pairs, quoted strings, lists, and nested list-of-dicts (for quiz questions).

### Rationale
1. **No external dependency**: Avoids adding Yams or similar library for a limited use case
2. **Controlled scope**: Only needs to parse the specific YAML subset used in PIRATEN-Kanon files
3. **Predictable behavior**: Custom parser handles exactly what we need, nothing more
4. **Nil on malformed**: Returns nil instead of crashing on unexpected input

### Consequences
- Cannot parse full YAML spec (anchors, multi-line strings, complex nesting)
- If content format evolves significantly, parser may need updates

---

## D-023: Native AttributedString for Markdown Rendering

**Date:** 2026-02-12
**Status:** Accepted

### Context
Knowledge lessons contain markdown content that needs rendering. Options:
1. WebView with markdown-to-HTML conversion
2. Third-party markdown library (e.g., MarkdownUI)
3. Native `AttributedString(markdown:)` (iOS 15+)

### Decision
Use native `AttributedString(markdown:)` with plain-text fallback on parsing failure.

### Rationale
1. **Zero dependencies**: Uses Foundation's built-in markdown parser
2. **Native look and feel**: Renders with system fonts and Dynamic Type
3. **Performance**: No WebView overhead
4. **Graceful fallback**: If markdown parsing fails, content still displays as plain text
5. **iOS 18+ target**: All modern AttributedString features available

### Consequences
- Limited to CommonMark subset supported by Foundation
- Complex HTML-style markdown (tables, footnotes) won't render styled
- Sufficient for the educational content format used in PIRATEN-Kanon

---

## Future Decisions

Decisions pending external input:
- meine-piraten.de authentication integration (when server adds auth)
- Todo pagination strategy (when data volume requires it)
- Knowledge progress sync across devices (if needed)
