# ADR-0010 — v1 cache in UserDefaults and filesystem

- **Status:** Accepted (supersedes [ADR-0005](./0005-offline-first-cache.md))
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** NFR-004, NFR-015

## Context

The documented cache technology ([ADR-0005](./0005-offline-first-cache.md))
was SQLite via GRDB. The implementation used two simpler mechanisms instead:

- `UserDefaults` with JSON-encoded values for small collections (forum
  topics, message threads, news items, reading progress, drafts).
- The filesystem (app support directory) for Kanon Markdown content.

Data volumes are small: a typical user sees tens to low hundreds of forum
topics, dozens of message threads, a few dozen news items. No complex
queries are needed — the app reads collections in full and the ViewModels
filter in memory.

Introducing SQLite + GRDB would add a dependency, require learning for new
contributors, and deliver no user-visible benefit at v1 scale. It would,
however, scale more gracefully if the data set grows into thousands of
objects.

## Decision

**v1 cache uses `UserDefaults` (for JSON-encoded collections) and the
filesystem (for Kanon content). No SQLite in v1.**

Stores:

| Store | Backing | Purpose |
|---|---|---|
| `DiscourseCacheStore` | UserDefaults (JSON) | Topics, message threads |
| `NewsCacheStore` | UserDefaults (JSON) | News items |
| `ReadingProgressStore` | UserDefaults | Per-topic reading progress, quiz state |
| `MessageDraftStore` | UserDefaults | Message drafts |
| `KnowledgeCacheManager` | Filesystem (app support dir) | Markdown + frontmatter |

All JSON stores implement a simple version-bump migration (NFR-015):
each store persists a schema version integer; on launch, if the stored
version is outdated, the cache is cleared and data is re-fetched from the
network. No data transformation is required because all cached data is
re-fetchable upstream.

## Consequences

- **Positive.** No third-party dependency. Small, debuggable, predictable.
  Writes are atomic at the `UserDefaults` level; the filesystem writes are
  isolated per file. Version-bump migrations solve the silent-empty-screen
  failure mode after app updates.
- **Negative.** No complex query ability. The entire cached collection is
  read into memory to render a tab. This is a non-issue at current scale
  but would become one if topic counts grew into the thousands.
- **Re-decision trigger.** If profiling shows cache read times exceeding
  100 ms on a typical device, or if we need to query (e.g. "all unread
  topics in pinned categories matching a keyword"), migrate to SQLite via
  GRDB. The repository pattern isolates each cache behind a protocol, so
  the change is local.
