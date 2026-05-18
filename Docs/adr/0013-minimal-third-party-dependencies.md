# ADR-0013 — Minimal third-party dependencies

- **Status:** Accepted
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** NFR-017

## Context

iOS development traditions range from "one library per problem" to
"write it yourself." The costs of each extra dependency in a small,
single-platform, open-source project are real:

- Each dependency is a supply-chain risk (maintenance, licensing,
  abandonment, compromised releases).
- Each dependency adds build time and binary size.
- Each dependency brings its own API that contributors must learn.
- Dependencies with wide surface areas (Markdown renderers, HTML parsers,
  networking stacks) couple the app to decisions the party does not own.

The alternative — hand-rolling everything — is worth the effort only when
the surface area the app actually uses is small. Many of the app's parsing
needs are narrow:

- iCal parsing: the app consumes a single `VEVENT` feed; it needs a few
  fields, not the full RFC 5545.
- Frontmatter parsing: the Kanon frontmatter is a small, fixed set of
  fields.
- HTML parsing: limited to extracting plain text and image references
  from Discourse post HTML.
- RSA: a single key-pair lifecycle for the Discourse User API Key
  handshake.

Implementations in the codebase for each of the above are small (dozens
to a few hundred lines), easy to audit, and aligned with the specific
needs of the app.

The only third-party dependency shipped today is **AppAuth-iOS**, which
is justified: OAuth 2.0 / OIDC / PKCE correctness is non-trivial, the
library is maintained by the OpenID Foundation, and re-implementing it
would be a security mistake.

## Decision

**New third-party dependencies require explicit justification in an ADR.**

The bar is: *the surface area we need is large enough that hand-rolling
is likely to be wrong*, or *the problem domain is security-critical
enough that using a well-audited implementation is strictly safer*.

Acceptable rationales:

- Cryptography beyond trivial uses (we do not roll our own crypto).
- Authentication protocols with subtle security properties (OAuth 2.0,
  OIDC).
- Domains where iOS does not ship a usable built-in (e.g. advanced
  Markdown rendering if that need arises).

Not acceptable rationales:

- "It has more features than we need." The extra features are a cost,
  not a benefit.
- "Everybody uses it." Popularity is not a technical argument.
- "It would save me an afternoon." Dependencies are a lifetime cost,
  not a one-time cost.

## Consequences

- **Positive.** Small binary. Fast builds. Any contributor can read the
  entire app without needing to learn external libraries. Supply-chain
  surface area is tiny.
- **Negative.** Some implementations are re-invented. The iCal parser,
  the frontmatter parser and the HTML parser each solve a slice of a
  problem that third-party libraries solve more completely. If a new
  use case expands those slices significantly, the re-decision trigger
  below applies.
- **Re-decision trigger.** If a feature requires Markdown rendering
  beyond what `MarkdownText` handles today, or richer HTML rendering,
  or any cryptographic work beyond the current RSA flow, propose a
  dependency in a new ADR.
