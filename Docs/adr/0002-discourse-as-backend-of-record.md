# ADR-0002 — Discourse is the backend of record

- **Status:** Accepted
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** FR-FORUM-*, FR-MSG-*, FR-NOTIF-*

## Context

The project's *reason to exist* is that the party's communication has
fragmented across many messengers and no canonical place remains. The proposed
canonical place is the Discourse instance at `diskussion.piratenpartei.de`:
it already exists, is operated by the party, supports structured discussion,
private messages, read state, search, moderation and per-user notifications.

Members' obstacle to using it is behavioural (messenger habits), not technical.
MeinePIRATEN is the mobile behaviour-bridge, not a new system.

If the app stored its *own* copies of discussion content, two consequences
would follow, both bad:

1. The app would become a second source of truth. Posts written in the app
   might or might not appear on Discourse; reactions might or might not cross
   over. This undoes the point of the project.
2. The effort to run a new backend would swallow the project. The party's
   volunteer capacity is limited; every component the app adds is a component
   someone must later operate.

## Decision

**Discourse is the backend of record for all discussion, private messages,
likes, notifications and user directory lookups.** The app is a client; it
reads from Discourse and writes to Discourse. It keeps a local cache for
responsiveness and offline reading, but the cache is advisory and Discourse's
state always wins on conflict.

## Consequences

- **Positive.** One source of truth. Members who use the web and the app see
  the same state. Moderation, search and backup remain Discourse's
  responsibility, not ours.
- **Negative.** We inherit Discourse's constraints: rate limits, the absence
  of native push, CSRF-style protections on some actions. These are addressed
  by the HTTP client ([architecture.md §3](../architecture.md)) and by
  [ADR-0006](./0006-notifications-v1-polling.md).
- **Implication.** Any feature proposal that would store conversational
  content solely on the device or on meine-piraten.de is rejected by default.
  Exceptions need an ADR that explicitly supersedes this one.
