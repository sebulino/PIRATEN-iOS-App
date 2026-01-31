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

## Future Decisions

Decisions pending external input:
- SSO provider and flow (see OPEN_QUESTIONS.md)
- Discourse authentication strategy
- meine-piraten.de API integration approach
