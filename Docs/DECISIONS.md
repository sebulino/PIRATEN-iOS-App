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

## Future Decisions

Decisions pending external input:
- SSO provider and flow (see OPEN_QUESTIONS.md)
- Discourse authentication strategy
- meine-piraten.de API integration approach
