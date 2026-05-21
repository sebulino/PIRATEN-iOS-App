# ADR-0009 — Discourse authentication via User API Key

- **Status:** Accepted
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** FR-AUTH-002, ADR-0003

## Context

After a user authenticates with PiratenSSO, the app needs to act as that
user against Discourse. Two approaches were considered
(see Q-013 in [`decisions-log.md`](../decisions-log.md)):

**Option A — Discourse SSO via PiratenSSO.** PiratenSSO acts as the SSO
provider configured in Discourse; the app rides the session cookie
obtained through a browser handshake.

**Option B — User-scoped Discourse API key.** The app obtains a per-user
User API Key via Discourse's `/user-api-key/new` endpoint and sends it
as a header on every request.

Option A would require cookie management in the app's HTTP stack, handling
CSRF tokens for state-changing requests, and carries a dependency on how
Discourse configures its SSO integration with Keycloak.

Option B is the pattern Discourse explicitly provides for mobile and
third-party clients. The key can be scoped to specific capabilities and
revoked by the user or by admins.

The implementation chose Option B, and it has been verified working
against the live Discourse instance.

## Decision

**The app authenticates with Discourse using a User API Key.**

Flow:

1. On first successful PiratenSSO login, the app generates an RSA key pair
   locally. The private key is stored in the Keychain.
2. The app opens a browser session (`ASWebAuthenticationSession`) to
   Discourse's `/user-api-key/new` endpoint, passing the public key and a
   nonce.
3. The user authorises the key in the Discourse web UI.
4. Discourse returns the User API Key encrypted with the app's public key.
5. The app decrypts the key with the private key and stores the plaintext
   key in the Keychain.
6. All subsequent Discourse requests carry `User-Api-Key: <key>` as the
   `DiscourseHTTPClient` header.

The RSA implementation is hand-rolled (`RSAKeyManager.swift`) in line with
[ADR-0013](./0013-minimal-third-party-dependencies.md).

## Consequences

- **Positive.** Uses the path Discourse publishes for exactly this use case.
  No cookie or CSRF machinery needed in the app's HTTP stack. The key can
  be revoked server-side.
- **Negative.** The handshake is a one-time extra browser trip after
  PiratenSSO login. Users see the Discourse authorisation page once.
- **Known gap (OPEN-02) — addressed by [ADR-0014](./0014-like-strategy-chain.md).**
  Like / unlike requests via the canonical `POST /post_actions.json`
  endpoint silently failed (2xx response, no persistence) on the live
  instance. ADR-0014 introduces a strategy chain that probes the
  reactions-plugin endpoint and a form-encoded variant before falling
  back to the original JSON request, with the winning strategy cached
  per install.
- **Lazy vs eager session validation.** The Android sibling app validates
  the User-Api-Key at startup with an explicit ping to Discourse and
  prompts for re-auth immediately if it fails. iOS does not. iOS instead
  relies on implicit validation: the notification poller's first call at
  `MainTabView` appearance hits an authenticated endpoint;
  `DiscourseHTTPClient` clears the credential on 401/403; `ForumView.task`
  re-triggers the handshake the next time the user lands on Forum. The
  trade-off — eager re-auth surfaces the problem sooner; lazy re-auth
  avoids interrupting users who don't visit Discourse-dependent tabs.
  Decided lazy for v1, see [Q-065](../decisions-log.md#q-065).
- **Failure modes.** If the key is revoked on Discourse (e.g. by an admin),
  subsequent requests return 401 and the app routes to a re-login flow.
  `handleAuthenticationError` currently does not implement this
  end-to-end — see [OPEN-09](../open-issues.md).
