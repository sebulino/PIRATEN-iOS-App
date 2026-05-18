# ADR-0003 — PiratenSSO is the sole identity provider

- **Status:** Accepted
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** FR-AUTH-*, NFR-006

## Context

Every member of the Piratenpartei already has a PiratenSSO account. The
organisation can provision, de-provision and recover those accounts. Any
identity model the app introduces on top would duplicate effort and weaken
the party's ability to revoke access when memberships end.

## Decision

**The app uses PiratenSSO as its sole identity provider.** There are no local
passwords, no "sign up with email", and no social logins. Tokens obtained
from PiratenSSO are used to authenticate against Discourse and
meine-piraten.de; how exactly that cross-authentication works is tracked in
[OPEN-07](../open-issues.md).

## Consequences

- **Positive.** Membership status is always correct by construction: if SSO
  revokes a user, they lose app access at the next token refresh. No separate
  user database, no password-reset flow, no GDPR exposure for credentials we
  never hold.
- **Negative.** Non-members cannot use the app. This is a feature, not a bug:
  the app is for members.
- **Operational.** A PiratenSSO outage is a full app outage. The Kajüte must
  degrade gracefully: if login fails, cached Kanon content is still readable,
  but everything user-specific is unavailable.
