# Threat Model

This document identifies security threats and mitigations for the PIRATEN iOS app.

Last updated: 2026-01-30
Current milestone: M1 (Bootstrap)

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
