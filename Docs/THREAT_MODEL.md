# Threat Model

This document identifies security threats and mitigations for the PIRATEN iOS app.

Last updated: 2026-02-12
Current milestone: M9 (Hardening & Governance)

---

## Overview

The app handles sensitive data:
- Member authentication credentials
- Personal communications (messages)
- Political discussion content
- Organization-internal tasks

**Threat actors:**
- Opportunistic attackers (device theft)
- Targeted attackers (political opposition, state actors)
- Malicious apps on shared device

---

## Assets

| Asset | Sensitivity | Storage |
|-------|-------------|---------|
| Auth tokens | High | Keychain |
| SSO credentials | Critical | Never stored (entered in web view) |
| Message content | High | Not persisted locally |
| User profile | Medium | Not persisted locally |
| App configuration | Low | xcconfig (build time) |

---

## Threats and Mitigations

### T-001: Token Theft via Device Compromise

**Threat:** Attacker gains physical access to unlocked device and extracts auth tokens.

**Mitigations:**
- Tokens stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Tokens not backed up to iCloud
- Consider: biometric re-authentication for sensitive actions (future)

**Residual risk:** Medium - tokens accessible while device unlocked

---

### T-002: Token Theft via Backup Extraction

**Threat:** Attacker extracts tokens from device backup.

**Mitigations:**
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` prevents Keychain backup
- No tokens stored in UserDefaults or files

**Residual risk:** Low

---

### T-003: Man-in-the-Middle Attacks

**Threat:** Attacker intercepts network traffic to steal credentials or tokens.

**Mitigations:**
- All API communication over HTTPS
- App Transport Security (ATS) enforced by iOS
- Certificate pinning (to be evaluated for future milestones)

**Residual risk:** Low with HTTPS, medium without pinning

---

### T-004: Credential Phishing

**Threat:** Malicious entity creates fake login page to capture credentials.

**Mitigations:**
- SSO login via `ASWebAuthenticationSession` (system browser)
- Users see actual SSO domain in browser
- App cannot access SSO credentials directly

**Residual risk:** Medium - users must verify domain

---

### T-005: Log Leakage of Sensitive Data

**Threat:** Tokens, PII, or message content logged and exposed via crash reports or shared logs.

**Mitigations:**
- KeychainService never logs values
- No PII in error messages
- Logging policy: no tokens, no credentials, no message content

**Residual risk:** Low if policy followed

---

### T-006: Insecure Data at Rest

**Threat:** Sensitive data stored in unprotected files on device.

**Mitigations:**
- No local caching of messages or forum content (thin client model)
- Tokens in Keychain only
- iOS file protection via Data Protection class (default encryption)

**Residual risk:** Low

---

### T-007: Session Hijacking

**Threat:** Attacker reuses stolen session token to impersonate user.

**Mitigations:**
- Tokens stored securely (see T-001)
- Token refresh mechanism (pending SSO details)
- Consider: device binding, token rotation (future)

**Residual risk:** Medium - depends on token lifetime

---

### T-008: Unauthorized Access After Logout

**Threat:** User logs out but tokens remain valid/stored.

**Mitigations:**
- Logout clears all Keychain tokens
- No offline cache of protected content

**Residual risk:** Low if logout properly implemented

---

## Privacy Considerations

### No Analytics
- No third-party analytics SDKs
- No usage tracking
- No behavioral profiling

### Data Minimization
- Thin client model: data stays on servers
- No local message storage
- Minimal profile data cached (if any)

### User Control
- Clear logout function
- No hidden data collection

---

## Trust Boundaries

This section identifies trust boundaries between the app and external systems.

### TB-001: App ↔ Piratenlogin SSO

**Boundary:** Authentication flow between iOS app and identity provider.

**Trust assumptions:**
- Piratenlogin is operated by the Piratenpartei
- HTTPS/TLS secures transport
- Identity provider validates credentials
- Tokens issued are cryptographically signed

**App responsibilities:**
- Never see or store user credentials (web view flow)
- Validate token signatures (if OIDC with JWT)
- Store tokens only in Keychain
- Handle token expiration gracefully

**Threats at boundary:**
- Malicious redirect URI hijacking
- Token interception (mitigated by HTTPS + system browser)
- Token replay (mitigated by short lifetime + refresh rotation)

---

### TB-002: App ↔ Discourse Forum API

**Boundary:** Data exchange between app and Discourse instance.

**Trust assumptions:**
- Discourse instance is operated by party or trusted entity
- API responses are trustworthy (no malicious HTML/content)
- Rate limiting protects against abuse

**App responsibilities:**
- Authenticate requests with valid token/session
- Sanitize any rendered content (avoid XSS if displaying HTML)
- Respect rate limits
- Do not cache sensitive forum content locally

**Threats at boundary:**
- Session fixation (if auth token shared with Discourse)
- Cross-site content injection in rendered posts
- Unauthorized data access if permissions not enforced server-side

---

### TB-003: App ↔ meine-piraten.de Todos API

**Boundary:** Data exchange for task management.

**Trust assumptions:**
- API operated by Piratenpartei infrastructure
- Access requires authenticated session
- Tasks contain potentially sensitive organizational data

**App responsibilities:**
- Authenticate all requests
- Do not expose task data to unauthorized users
- Clear any cached task data on logout

**Threats at boundary:**
- Unauthorized task visibility if permissions misconfigured
- Data leakage if tasks cached insecurely

---

### TB-004: App ↔ Device Keychain

**Boundary:** Sensitive data storage on device.

**Trust assumptions:**
- iOS Keychain provides hardware-backed encryption
- Only our app can access items with correct access group
- Data is protected at rest and in transit within secure enclave

**App responsibilities:**
- Use appropriate accessibility level (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
- Never log Keychain values
- Clear Keychain on logout
- Consider biometric protection for high-sensitivity operations

**Threats at boundary:**
- Jailbreak/device compromise bypasses OS protections
- Backup extraction (mitigated by ThisDeviceOnly attribute)

---

## Token Security (Detailed)

### Access Token Handling

**Storage:**
- Keychain only with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Never in UserDefaults, files, or in-memory beyond session

**Lifetime:**
- Access tokens should be short-lived (pending SSO details)
- Refresh tokens used for session continuity
- App must handle expiration gracefully (refresh or re-auth)

**Transmission:**
- TLS 1.2+ required for all API calls
- Tokens in Authorization header only, never in URLs

### Refresh Token Handling

**Storage:**
- Same Keychain protections as access token
- Consider additional biometric protection for refresh token retrieval

**Rotation:**
- If SSO supports rotation, old refresh tokens must be invalidated after use
- App must handle rotation failures (re-authenticate user)

**Revocation:**
- Logout must revoke tokens server-side if endpoint available
- Local token deletion alone is insufficient

### Token Validation

**If using OIDC/JWT:**
- Validate signature against known keys
- Check `iss` (issuer) matches expected identity provider
- Check `aud` (audience) includes our app client ID
- Check `exp` (expiration) is in the future
- Check `iat` (issued at) is reasonable

---

## Local Storage Security

### Principle: Thin Client

The app follows a thin-client model to minimize local data exposure:
- No persistent caching of forum posts or messages
- No local database of tasks (fetch on demand)
- User profile may be cached temporarily for display only

### What MAY be stored locally

| Data | Storage | Protection | Cleared on Logout |
|------|---------|------------|-------------------|
| Access token | Keychain | Hardware encryption | Yes |
| Refresh token | Keychain | Hardware encryption | Yes |
| User display name | Memory only | None (non-sensitive) | Yes (app termination) |
| User ID | Memory only | None | Yes |

### What MUST NOT be stored locally

- User credentials (password never seen by app)
- Private messages content
- Forum post content (beyond current session)
- Task descriptions (beyond current session)
- Member email addresses
- Organizational membership details

---

## Member Data Exposure

### Data Classification

**Critical (never stored/logged):**
- Passwords, PINs, secrets
- Full authentication tokens in logs

**High sensitivity:**
- Email addresses
- Real names
- Membership status
- Payment information (not applicable to this app)

**Medium sensitivity:**
- Username
- Group memberships
- Forum activity

**Low sensitivity:**
- Public forum posts (already public)
- App configuration

### Exposure Mitigation

1. **Display only:** Member data shown but not persisted
2. **No screenshots:** Consider preventing screenshots of sensitive screens (future)
3. **No clipboard:** Sensitive data not auto-copied
4. **Redaction:** Logs must redact PII automatically

---

## Messaging Write Actions (M4)

This section documents security considerations for messaging write operations introduced in M4.

### T-009: Message Flooding / Abuse

**Threat:** Attacker or compromised account sends rapid messages to abuse the system or harass users.

**Mitigations:**
- Client-side rate limiting: one send at a time + 3 second cooldown
- Input length constraints: max 10,000 characters
- Server-side rate limits via Discourse (20 req/min, 2,880 req/day)
- No support for attachments (reduces abuse surface)

**Residual risk:** Low - multiple layers of rate limiting

---

### T-010: Message Content Leakage via Logs

**Threat:** Message content logged and exposed via crash reports, device logs, or debugging.

**Mitigations:**
- `MessageSafetyService` and `MessageThreadDetailViewModel` explicitly avoid logging content
- Validation methods process content without logging the actual text
- Error messages contain no user content or identifiers
- All code has privacy documentation comments enforcing this policy

**Residual risk:** Low if policy followed

---

### T-011: Unauthorized Message Sending

**Threat:** Attacker sends messages as another user via token theft or session hijacking.

**Mitigations:**
- Token stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- AuthenticatedHTTPClient validates token before each request
- Token refresh enforced per M3a rules
- Unauthenticated users see login prompt instead of composer

**Residual risk:** Medium - depends on token security (see T-001, T-007)

---

### T-012: Input Validation Bypass

**Threat:** Malformed or malicious content bypasses client validation and reaches server.

**Mitigations:**
- Client-side validation via `MessageSafetyService.validate()`
- Server-side validation by Discourse (authoritative)
- Only plain text supported; no rich formatting or HTML allowed in composer
- Content trimmed and length-checked before submission

**Residual risk:** Low - server is authoritative

---

### T-013: Replay Attacks on Message Send

**Threat:** Attacker replays a captured message POST request.

**Mitigations:**
- TLS 1.2+ required for all API calls
- Bearer token in Authorization header (not URL)
- Discourse enforces topic_id validity and user permissions
- Duplicate detection handled server-side

**Residual risk:** Low

---

## Push Notifications (M5)

This section documents security and privacy considerations for push notifications introduced in M5.

### T-014: Push Notification Content Leakage

**Threat:** Sensitive message content or user information exposed via push notification payloads.

**Attack vectors:**
- Notification banners visible on lock screen
- Notification history accessible to unauthorized users
- APNs payloads transit through Apple's servers (not E2E encrypted)
- Shoulder surfing when notification appears
- Forensic analysis of notification history

**Mitigations:**
- **Content prohibition:** Message content NEVER included in payload
- **Generic text only:** "Du hast eine neue Nachricht" not "Klaus: Hi there"
- **No usernames:** Sender/recipient names not in payload
- **Minimal routing data:** Only deepLink type + ID for navigation
- **User control:** Notifications opt-in only (default off)
- **Clear policy:** Backend implementation must enforce content restrictions

**Residual risk:** Low if payload policy strictly enforced

**Implementation notes:**
- App fetches actual content after user taps notification and authenticates
- Deep link contains only topicId/todoId, not content preview
- Badge count shows unread total but no per-conversation details

---

### T-015: Device Token Theft and Impersonation

**Threat:** Attacker obtains device token and sends unauthorized push notifications.

**Attack vectors:**
- Device token stolen from backend database
- Man-in-the-middle during token registration
- Token reused after user logs out

**Mitigations:**
- **Token transmission security:** HTTPS only for registration endpoint
- **Backend validation:** Verify user owns the device before accepting token
- **Token revocation:** Clear tokens on logout (client and server)
- **APNs auth security:** Server-side APNs keys never exposed to client
- **Rate limiting:** Prevent token registration spam

**Residual risk:** Medium - depends on backend security

**Implementation notes:**
- Device tokens are non-sensitive (designed to be stored openly)
- Actual threat is unauthorized notification sending, not token theft itself
- APNs enforces bundle ID matching, preventing cross-app token abuse

---

### T-016: Notification Metadata Leakage

**Threat:** Notification metadata (timing, frequency, badge count) reveals user behavior patterns.

**Attack vectors:**
- Notification arrival times reveal when user receives messages
- Badge count exposes unread message volume
- Notification frequency shows conversation activity

**Mitigations:**
- **Awareness:** Users informed that notification timing is observable
- **Opt-in only:** Notifications disabled by default
- **No analytics:** App does not track notification opens/dismissals
- **Clear settings:** Transparent controls for enabling/disabling per category

**Residual risk:** Medium - metadata always observable by Apple/network

**Accepted trade-off:** Real-time notifications inherently leak timing metadata. This is disclosed to users via settings UI.

---

### T-017: Notification Spoofing

**Threat:** Malicious actor sends fake push notifications pretending to be from the app.

**Attack vectors:**
- Compromised backend server
- Stolen APNs authentication credentials
- Phishing via fake notifications

**Mitigations:**
- **APNs authentication:** Only backend with valid APNs key can send
- **Bundle ID enforcement:** APNs validates bundle ID matches certificate
- **Backend security:** APNs auth keys stored securely (not in code)
- **Key rotation:** Regular rotation of APNs authentication keys
- **User education:** App UI clearly identifies official notifications

**Residual risk:** Low if backend security maintained

---

### T-018: Privacy Violation via Notification Aggregation

**Threat:** Third-party notification aggregators or analytics tools collect notification metadata.

**Mitigations:**
- **No tracking SDKs:** App includes no analytics or notification tracking
- **Generic content:** Payloads contain no identifying information
- **iOS privacy:** System manages notification display, not app
- **User control:** iOS notification settings allow complete disabling

**Residual risk:** Low - iOS system notifications provide baseline privacy

---

## Push Notification Privacy Requirements (Summary)

**Payload Content Policy:**
- ✅ Generic alert text only
- ✅ Deep link routing IDs (topicId, todoId)
- ✅ Badge counts
- ❌ Message content or previews
- ❌ Usernames or display names
- ❌ Subject lines or titles
- ❌ Any PII beyond minimum for routing

**Backend Requirements:**
- Device tokens stored securely with user association
- Tokens cleared on logout (client-initiated or server timeout)
- APNs auth keys never exposed to clients
- Notification sending respects user's enabled categories
- No tracking or analytics of notification delivery

**User Controls:**
- All notifications opt-in (default disabled)
- Per-category toggles (Messages, Todos)
- Clear explanation of what is sent
- Easy access to iOS system settings

---

## Future Considerations

As features are implemented, this document will be updated:

1. **Authentication (M2):**
   - SSO flow security review
   - Token storage implementation audit
   - Session timeout handling

2. **Forum Integration (M3+):**
   - Discourse API authentication review
   - Content display security (XSS in web views if used)
   - Link handling

3. **Messaging:**
   - End-to-end encryption status (depends on Discourse)
   - Message notification content
   - Attachment handling

---

## Incident Response

If a security issue is discovered:
1. Document in this file under "Known Issues"
2. Assess severity and exploitability
3. Implement fix before next release
4. Consider disclosure timeline

---

## M9 Security Hardening (2026-02-12)

### Logging Audit Results

A full audit of all 117 Swift source files was conducted. Two sensitive logging issues were found and remediated:

1. **DiscourseAuthManager: Public key PEM logged at DEBUG level** (Medium risk)
   - Full RSA public key was logged via `discourseAuthLog.debug()`
   - Fix: Removed PEM logging; only key length is logged

2. **DiscourseAuthManager: Decrypted auth payload logged at DEBUG level** (High risk)
   - The full decrypted JSON including the Discourse User API Key was logged
   - Fix: Removed payload logging; only byte count is logged

3. **DiscourseAuthManager: Callback URL logged with full query/fragment** (Medium risk)
   - The full callback URL including encrypted payload data was logged
   - Fix: URL logged via `LogRedactor.redactURL()` (scheme + host + path only)
   - Query item values replaced with name-only listing

### Centralized Redaction

`LogRedactor` utility added (`Core/Support/LogRedactor.swift`) providing:
- `redactSecret(_:)` — shows only a configurable prefix + total length
- `redactURL(_:)` — strips query parameters and fragments
- `redactData(_:)` — logs byte count only

All future logging of sensitive values MUST use these helpers.

### Security Assumptions Documented

- Apple `os.log` Logger DEBUG/INFO levels are **not** privacy-redacted by default
- DEBUG-level logs persist in unified log and are readable via Console.app
- Even public keys should not be fully logged (fingerprinting risk)
- Encrypted payloads must not be logged (may be replayed or decrypted offline)

### Remaining Safe Logging Patterns

The following patterns were reviewed and confirmed safe:
- `#if DEBUG`-guarded `print()` statements (5 instances across AppDelegate, DeviceTokenManager)
- Nonce prefix logging (`nonce.prefix(16)`) — safe partial disclosure
- URL length logging — safe metadata only
- Token prefix logging in DeviceTokenManager — safe, DEBUG-only

---

## Known Issues

(None at this time)
