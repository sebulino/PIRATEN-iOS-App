# ADR-0016 — No certificate pinning for v1

- **Status:** Accepted
- **Date:** 2026-05
- **Deciders:** Sebastian Alscher
- **Related:** NFR-013 (transport security), Security Audit 2026-05-21
  (MASVS-NETWORK-2), ADR-0009 (Discourse auth), ADR-0013 (minimal
  third-party dependencies)

## Context

The May 2026 security audit flagged MASVS-NETWORK-2 (Certificate Pinning) as
**Absent** with no documented rationale. The OWASP MASVS classifies absence
as a finding by default — a missing control without explicit justification
reads to an external auditor as oversight rather than considered design.

The app talks to three production endpoints, all under the party's control:

- `sso.piratenpartei.de`            — Keycloak (PiratenSSO)
- `diskussion.piratenpartei.de`     — Discourse forum + messages
- `meine-piraten.de`                — Rails backend for News / Todos
- `agitatorrr.de`                   — iCal calendar feed
- `api.github.com`                  — Knowledge-base content (ADR-0011)

Three options were considered:

**Option A — Implement certificate pinning for v1.** Ship the app with a
hard-coded set of leaf or intermediate certificate fingerprints, validated
in a `URLSessionDelegate` that rejects any handshake that does not match.

  - *Attractive:* eliminates the trust-store-compromise attack class for
    party-controlled hosts. Demonstrates security maturity.
  - *Rejected for v1:* the party's infrastructure rotates certificates
    on the standard 90-day Let's Encrypt cadence (and ad-hoc on incidents),
    none of which the iOS team controls or is notified about. A silent
    cert rotation would brick every installed copy of the app until a
    forced TestFlight update propagated — for users who happen to have
    background-app-refresh disabled, the app would simply stop working
    with no diagnostic. The infrastructure for pin rotation
    (e.g. server-pushed pin updates, dual-pin strategy with backup pins)
    does not exist on either side. Implementing it correctly is a
    multi-week, multi-org effort that delays v1 ship without a
    proportionate threat-model benefit (see below).

**Option B — Implement subjectPublicKeyInfo (SPKI) pinning with backup
pins.** Same as A but pin the SPKI of the issuing intermediate CA instead
of the leaf, with a documented backup pin for the next rotation.

  - *Attractive:* survives Let's Encrypt leaf rotation. Backup pin gives
    a recovery path without a forced app update.
  - *Rejected for v1:* still requires the iOS team to be in the loop on
    CA migrations, which has happened twice in the last 18 months across
    the party's infrastructure (DST Root CA X3 → ISRG Root X1 → ISRG
    Root X2). The operational cost is real and the team is too small to
    absorb it for v1.

**Option C — Rely on the system TLS trust store + Apple's App Transport
Security (ATS) defaults.** No app-level pinning; explicitly document the
decision and revisit post-v1.

The threat model justifies Option C as a deliberate v1 choice:

- The realistic attacker against an authenticated member of a political
  party is not a state-level adversary willing to mint a rogue cert from
  a public CA. It's the much-larger pool of network adversaries on the
  authenticated user's WiFi or carrier path.
- ATS already mandates TLS 1.2+, forward secrecy, and certificate
  transparency — the standard defences against passive interception and
  most cert-mis-issuance scenarios are already in force.
- The app stores no long-lived bearer credentials that survive device
  migration (Keychain `ThisDeviceOnly`, see ADR-0009).
- The Discourse User API Key can be revoked per-device server-side at
  any moment by the user (revoke flow exists, see security audit H-2).

The threat that *would* justify pinning — a rogue intermediate cert
mis-issued for `*.piratenpartei.de` and used to MITM authenticated app
traffic — exists, but the cost of a working pinning implementation in
v1 (operational + delay-to-ship) outweighs the marginal benefit over
ATS in this specific context. Post-v1, this calculus is expected to
shift as the app grows beyond the initial member audience.

## Decision

**The app does not implement certificate pinning for v1.** Transport
security relies on Apple's App Transport Security defaults: enforced
TLS 1.2+, perfect forward secrecy, certificate transparency, and the
system trust store. No `URLSessionDelegate` overrides
`urlSession(_:didReceive:completionHandler:)` for certificate
validation.

The decision is documented in this ADR so MASVS-NETWORK-2 is **Intentional
(Not Implemented)** rather than **Absent (Undocumented)**.

## Consequences

- **Positive.** No risk of bricking the installed app via cert rotation.
  No need for pin-update infrastructure on either side. Ships v1 on
  schedule. Operational cost for cert changes is zero — the party's
  infrastructure team can rotate certs without coordinating with iOS.

- **Negative.** A state-level or CA-compromise adversary capable of
  obtaining a valid cert for `*.piratenpartei.de` from a CA in Apple's
  trust store can MITM the app's traffic. Mitigated but not eliminated
  by ATS + certificate transparency.

- **Negative.** The app cannot detect a captive-portal or corporate-proxy
  TLS inspection (which by design installs a trusted root that ATS
  accepts). Members on monitored networks have no app-level signal that
  their traffic is being inspected.

- **Follow-ups.**
  - **Reversal trigger:** if the party adopts a stable, documented
    cert-rotation process with iOS-team notification, OR if a member
    incident occurs that pinning would have prevented, revisit and
    likely move to Option B (SPKI pinning with backup pin).
  - **Post-v1 backlog:** file a tracking issue for "implement SPKI
    pinning with dual-pin strategy" once v1 has shipped and the
    operational picture is stable.
  - **Documentation:** update `Docs/THREAT_MODEL.md` to reflect this
    decision under T-008 (network-layer adversary). Update `Docs/security-audit-2026-05-21.md`
    to mark MASVS-NETWORK-2 as Intentional with a link to this ADR.
