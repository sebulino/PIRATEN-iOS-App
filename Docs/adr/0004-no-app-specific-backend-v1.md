# ADR-0004 — No app-specific backend in v1

- **Status:** Accepted
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** ADR-0002, ADR-0006, OPEN-01

## Context

A dedicated backend for MeinePIRATEN (e.g. a small service that aggregates
Discourse + Agitatorrr + news + ToDos, dispatches push notifications, and
smooths over rate limits) would make the app nicer. It is also a system
someone must operate for the lifetime of the app. Volunteer operational
capacity in the party is scarce and already stretched.

The risk of introducing a backend before the app has proven useful is that
the backend becomes the bottleneck to shipping v1.

## Decision

**v1 ships without an app-specific backend.** The app talks directly to
Discourse, Agitatorrr, meine-piraten.de (for News and ToDos), GitHub (for the
Kanon), and PiratenSSO. Each integration is accessed through an isolated
adapter so a backend can be inserted later without reshaping the app.

## Consequences

- **Positive.** Lower operational burden. Smaller attack surface. No new
  service to harden, monitor, back up or GDPR-audit. The project can ship.
- **Negative.** Some features are constrained:
  - Push notifications are not possible without a relay; v1 therefore polls
    ([ADR-0006](./0006-notifications-v1-polling.md)).
  - Client-side rate-limit pressure on Discourse scales with user count.
- **Trigger for re-decision.** When any of the following become true, revisit:
  (a) push notifications are required for adoption, (b) Discourse rate limits
  become a user-visible problem, (c) a party-operated service already exists
  that can absorb the role.
