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

## Future Decisions

Decisions pending external input:
- Discourse authentication strategy verification (see OPEN_QUESTIONS.md)
- meine-piraten.de API integration approach
