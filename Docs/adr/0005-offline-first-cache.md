# ADR-0005 — Offline-first cache with SQLite / GRDB

- **Status:** Superseded by [ADR-0010](./0010-v1-cache-in-userdefaults-and-filesystem.md)
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher

## Superseded

This ADR proposed SQLite via GRDB as the cache technology. The implementation
went a different route (UserDefaults + filesystem JSON) and the team accepted
that approach as sufficient for v1. See [ADR-0010](./0010-v1-cache-in-userdefaults-and-filesystem.md)
and Q-005 in [`decisions-log.md`](../decisions-log.md).

The original text is kept here for historical context.

---

## Original context

Target users open the app for brief windows on mobile networks. Two failure
modes would ruin the experience:

1. A blocking network call on launch leaves the user staring at a spinner.
2. A transient upstream failure breaks a tab the user was not even visiting.

The app must render from local data first and reconcile with the network in
the background. This implies a real local store, not ad-hoc caches.

Alternatives considered:

- **`URLCache`.** HTTP-layer caching is too crude; it does not help with
  domain queries and does not survive the kind of schema the app needs.
- **Core Data.** Capable but heavy, with a migration story that has
  historically absorbed a lot of iOS project time.
- **Realm.** Capable but an external dependency.
- **SwiftData.** Newer, still maturing.
- **GRDB on SQLite.** Thin, well-maintained, idiomatic Swift.

## Original decision

Use **SQLite via GRDB** as the single local store. One database file,
per-feature DAOs, one writer queue, arbitrary readers. Schema migrations are
versioned in code.

## Why this was superseded

The implementation team built caches using `UserDefaults` (for JSON-encoded
small collections) and the filesystem (for Kanon Markdown content) instead.
The data volumes are small and the repository pattern isolates each cache,
making a future GRDB migration possible if needed but not necessary for v1.
Introducing GRDB at this stage would add a dependency without shipping a new
user-visible benefit.

See [ADR-0010](./0010-v1-cache-in-userdefaults-and-filesystem.md).
