# ADR-0007 — Kanon is pinned to a commit per release

- **Status:** Superseded by [ADR-0011](./0011-kanon-sha-tracking.md)
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher

## Superseded

This ADR proposed per-release commit pinning for the Kanon with a bundled
fallback. The chosen approach is different: the app tracks the SHA of the
last successfully downloaded Kanon content and re-downloads when the
remote SHA changes. See [ADR-0011](./0011-kanon-sha-tracking.md) and Q-025
in [`decisions-log.md`](../decisions-log.md).

The original text is kept for historical context.

---

## Original context

The Wissen tab renders content from the PIRATEN-Kanon repository. Two
failure modes had to be avoided:

1. Breaking changes in the Kanon break the app for installed users.
2. Apple review must be reproducible.

## Original decision

Each app release would pin a specific commit SHA of the Kanon as its
baseline. The pinned content would be bundled into the app binary so the
first launch works offline. After launch, the app could fetch an updated
`index.json` manifest from the same repo; compatible entries would be
downloaded and cached.

## Why this was superseded

The project owner preferred a simpler update model that does not couple
Kanon content freshness to app release cadence. A SHA-tracking approach
achieves the same safety against broken commits (if GitHub returns an
error or unparseable content, the locally cached version is retained)
without the operational overhead of bundling content into every app
release.

See [ADR-0011](./0011-kanon-sha-tracking.md).
