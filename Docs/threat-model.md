# Threat Model

**Last reviewed:** 2026-04-20
**Next review due:** Before v1 TestFlight release, then at minimum every
major release.

This is a lightweight threat model focused on the realistic risks facing a
members-only party communication app. It is not an exhaustive STRIDE
analysis; it is a living document that helps reviewers ask the right
questions.

---

## 1. Assets

What we are protecting, in order of sensitivity:

1. **Member identity and credentials** — PiratenSSO tokens, the Discourse
   User API Key.
2. **Private message content** — DMs between members, feedback submissions,
   admin requests.
3. **Member association** — the fact that a given person is a party
   member (not just the content of their messages).
4. **Forum read state and activity patterns** — which topics a member
   reads, when, from where.
5. **Service availability** — ability of the app and its upstreams to
   function for members.

---

## 2. Adversaries

Who we plausibly need to defend against:

| Adversary | Capability | Motivation |
|---|---|---|
| Casual attacker on public Wi-Fi | Can intercept unencrypted traffic | Opportunistic data capture |
| Malicious app on the same device | Limited inter-app sandbox | Access tokens, copy sensitive data |
| Lost or stolen device | Physical access to a locked phone | Access to stored tokens and cached content |
| Adversarial party (internal or external) | Targeted surveillance of a specific member | Identify party members, their activity, their contacts |
| Upstream compromise | Discourse, meine-piraten.de, Agitatorrr, GitHub | Injection of hostile content |
| Bad actors authenticated as members | Valid PiratenSSO credentials | Abuse of in-app features (spam, harassment, impersonation) |

Out of scope (but acknowledged):

- Nation-state-level adversaries with zero-day iOS exploits.
- Physical coercion of the user.
- Supply-chain attack on the iOS platform itself.

---

## 3. Mitigations in place

### Transport

- All network traffic is HTTPS with App Transport Security (ATS)
  enforced. No `NSAllowsArbitraryLoads`.

### Credentials at rest

- All tokens (PiratenSSO access, refresh, ID token; Discourse User API
  Key) are stored in the iOS Keychain with
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Tokens are not synced via iCloud and do not survive device migration.
  A new device requires re-authentication.

### Authentication

- OAuth 2.0 / OIDC with PKCE via `ASWebAuthenticationSession`. No
  embedded web views for login.
- Discourse access uses a short-lived-by-admin-revocation User API Key
  obtained through an RSA-encrypted handshake (ADR-0009).
- No local passwords. No social logins.

### Logging

- A central `Logger` facade wraps `os.Logger`.
- Any log call that could include user data, tokens or PII must pass
  through `LogRedactor` (NFR-010).
- No raw `print(...)` calls in shipped code.
- No third-party analytics or crash reporters in v1.

### Dependencies

- Only one third-party dependency: AppAuth-iOS (OpenID Foundation).
  Supply-chain surface area is minimal (ADR-0013).

### Data minimisation

- The app collects no telemetry in v1.
- Cache contents are re-fetchable; no app-generated user data is
  persisted beyond what upstreams already hold.
- Keychain contents are wiped on logout.

### Notifications (T-007)

- Local notifications **may name the item that triggered them** — the
  forum topic title, the private-message sender + subject, the todo or
  news title. Previously every body was generic; this was loosened for
  parity with the Android app and for usefulness. Bodies are built on
  the fly by `NotificationContentBuilder` from data already fetched for
  the poll; **no notification text is ever persisted** (only aggregate
  `bg_*` ids/counts are stored, for change detection).
- **Wissen** and **Termine** stay generic: a changed knowledge slug
  can't be named meaningfully, and event detection is count-based so it
  cannot identify *which* event is new.
- **Private-message bodies are sensitive** (they reveal a sender and
  subject). iOS has no per-notification redaction API (no equivalent of
  Android's `setPublicVersion`). Instead we rely on the system-wide
  *"Vorschau zeigen: Wenn entsperrt"* default, which hides the body on a
  locked screen and reveals it only after Face/Touch ID. The builder
  marks such content `isLockscreenSensitive`, but that flag is
  informational — it does not change scheduling. A user who has switched
  previews to *"Immer"* will see message senders/subjects on the lock
  screen; this is their explicit OS-level choice.
- Notification bodies still contain no tokens, no email addresses, no
  membership data, and no full message contents — only the single
  newest item's title/sender.
- **Categories default on (opt-out, Q-068)** for parity with the Android
  app. This is bounded: iOS still requires an explicit system-permission
  grant before *any* notification is delivered (requested in-context
  after login, not cold on first launch), detection stays polling-only
  (no third-party push server sees metadata, cf. Q-067), and members can
  switch any category off — a choice that persists and overrides the
  default. On logout the per-category flags revert to the uniform default
  rather than leaking the previous user's selections (M-2).

### Input handling

- Content from Discourse is rendered with bounded interpreters
  (SwiftUI Text, a narrow HTML→plain-text pipeline, a hand-written
  Markdown renderer). No `WKWebView` rendering of arbitrary third-party
  HTML.
- External links in News items open in `SFSafariViewController`, which
  isolates browsing from the app's keychain and storage.

---

## 4. Residual risks

Risks we do not fully mitigate, and why:

| Risk | Rationale for accepting |
|---|---|
| Compromise of a single upstream injects hostile content | NFR-005 (failure isolation) limits blast radius per tab, but a malicious Discourse post could still target a user. Mitigated by content rendering avoiding `WKWebView` and by Discourse's own moderation. |
| Lost unlocked device gives full app access | iOS-level passcode / biometrics protect the device; the app does not add a second factor in v1. FR-AUTH-006 (biometric re-auth) is deferred to post-v1. |
| Anonymous GitHub rate limit (60 req/h/IP) shared across a location | Accepted for v1 (Q-027). Failure mode is a stale Kanon, not data exposure. |
| Likes not syncing upstream (OPEN-02) | Data integrity issue, not a security issue — but worth listing because users may see state that does not match server reality. |
| No crash reporting | Reduces telemetry but also means real crashes may go unnoticed. Crash reporting is planned post-v1 with a privacy review. |

---

## 5. Review triggers

Re-review this document whenever any of the following happen:

- A new third-party dependency is added (ADR-0013 requires an ADR anyway).
- A new upstream integration is introduced.
- A change to how tokens or cached content are stored.
- A change to logging or a new log site that could carry user data.
- A new category of user content is rendered (e.g. video, arbitrary HTML,
  executable content of any kind).
- Post-v1, when crash reporting or telemetry is introduced.
