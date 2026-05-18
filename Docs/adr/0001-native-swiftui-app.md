# ADR-0001 — Native SwiftUI app on iOS

- **Status:** Accepted
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** NFR-001, NFR-003

## Context

The project targets members of the Piratenpartei who currently rely on
messenger apps with a "open the phone for five minutes" interaction style. To
fit that behaviour the app must feel native: fast cold start, native
navigation, background refresh, EventKit integration, Keychain, VoiceOver,
Dynamic Type.

Alternatives considered:

- **React Native / Flutter / Capacitor.** Cross-platform saves effort *if*
  Android is also built. Android is out of scope for v1 and the party has no
  resourced Android effort lined up. Cross-platform imposes permanent overhead
  (bridging, release process, tooling) for a benefit we do not yet collect.
- **Progressive Web App.** Loses Keychain, EventKit, proper local
  notifications, and App Library presence. Worst, it mirrors exactly the
  "go to a website" pattern we are trying to replace.
- **UIKit.** Mature and capable but verbose for a small team. SwiftUI covers
  this app's surface with less code.

## Decision

Build a **native iOS app in Swift, with SwiftUI as the primary UI framework**,
falling back to UIKit only where SwiftUI has known gaps (e.g.
`ASWebAuthenticationSession`, `SFSafariViewController`, selectable text via
`UIViewRepresentable`).

**Minimum iOS version: iOS 26.2. iPhone only.** iPad support is explicitly
out of scope for v1.

## Consequences

- **Positive.** Best-in-class platform integration, small codebase, fast
  iteration. First-class Keychain, EventKit, local notifications, VoiceOver.
  iOS 26.2 minimum means the project can use the newest platform APIs
  without compatibility shims.
- **Negative.** No Android users in v1. Users on iPhones older than iOS 26.2
  cannot install the app. The party must accept both trade-offs explicitly —
  a future Android version will be a separate project, not a rebuild.
- **Follow-ups.** If an Android need emerges, revisit via a new ADR; do not
  retrofit cross-platform onto the iOS codebase. The cross-platform
  non-functional requirements (NFR-002, NFR-014) are written to apply to any
  future MeinePIRATEN implementation.
