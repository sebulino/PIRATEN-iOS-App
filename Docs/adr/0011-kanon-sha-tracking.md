# ADR-0011 — Kanon SHA tracking

- **Status:** Accepted (supersedes [ADR-0007](./0007-kanon-pinned-by-commit.md))
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** FR-KNOW-002

## Context

The Wissen tab renders content from
<https://github.com/sebulino/PIRATEN-Kanon>. Two failure modes must be
avoided:

1. A bad Kanon commit breaks the Wissen tab for all installed users
   immediately.
2. Offline first launch: the user opens the app on a tram with no network;
   the tab should still show something.

[ADR-0007](./0007-kanon-pinned-by-commit.md) originally proposed per-release
commit pinning with a bundled fallback. The project owner preferred a
simpler update model that does not couple Kanon freshness to app release
cadence — the reference corpus should be improvable without shipping a new
app build.

## Decision

**The app tracks the commit SHA of the last successfully downloaded Kanon
content.**

Flow:

1. On startup (in the background, non-blocking), the app queries the
   latest commit SHA for the configured branch of the Kanon repo via
   GitHub's API.
2. If the remote SHA differs from the SHA stored in `KnowledgeCacheManager`,
   the app downloads the new content and updates the cache and the stored
   SHA.
3. If GitHub is unreachable, or the download fails, or the new content
   fails to parse, the previously cached content and its stored SHA are
   retained unchanged. The Wissen tab continues to show the last known
   good state.

No per-app-release pinning. No bundled content in the app binary. First
launch without a network shows an empty state with a retry affordance.

## Consequences

- **Positive.** Kanon improvements reach users without an app release.
  A bad commit does not brick installed apps as long as the app detects
  the parse failure (which it must — this is a code correctness
  requirement). The SHA check is a single cheap call per startup.
- **Negative.** First launch without a network shows an empty state.
  Users who install and immediately open the app in a no-signal area see
  no Wissen content. This is judged acceptable because the typical install
  flow has network available, and subsequent launches use the cache.
- **Implication.** The app must detect parse failures defensively. If a
  downloaded Kanon file fails frontmatter or section parsing, that file is
  rejected and the previous cached version is kept. This is an NFR-005
  (resilience) requirement applied to the Kanon upstream.
- **Rate limits.** GitHub's anonymous API is 60 req/h/IP. The SHA check is
  one request; downloading the Kanon after a SHA change is typically tens
  of requests. Accepted for v1.
