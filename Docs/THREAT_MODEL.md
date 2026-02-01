# Threat Model

This document identifies security threats and mitigations for the PIRATEN iOS app.

Last updated: 2026-01-30
Current milestone: M2b (Integration Stubs)

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

## Known Issues

(None at this time)
