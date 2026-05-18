# ADR-0012 — Repository pattern with Real / Fake split

- **Status:** Accepted
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** NFR-016

## Context

Every feature in the app accesses its backing data through a repository
protocol — `DiscourseRepository`, `KnowledgeRepository`,
`CalendarRepository`, `TodoRepository`, `NewsRepository`,
`AuthRepository`. This layering was enforced from the start of development
and has proven valuable: ViewModels never know whether they are talking
to a live API, a cache, or a test stub.

The original implementation shipped `Fake<Feature>Repository` variants
alongside `Real<Feature>Repository`, with both wired into `AppContainer`.
The fakes returned stubbed content. This made some screens feel populated
during development without a working network — but it also meant the
developer experience and the production experience diverged. A screen that
looked fine with fake data could break when real data arrived in a
different shape or arrived not at all.

A cleaner split is: fakes exist to make tests fast and deterministic;
production uses the real repository and shows honest loading / empty
states while data loads from cache or network.

## Decision

**Every feature is accessed through a `<Feature>Repository` protocol with
a clear Real / Fake split:**

- `Real<Feature>Repository` is the only implementation wired into
  `AppContainer` in dev and production builds.
- `Fake<Feature>Repository` implementations exist in `PIRATENTests/` only.
  They are never wired into the running app.
- In-flight and empty-cache states are rendered as skeleton or placeholder
  UI — never as fake data.

Each feature lives in `Core/Domain/<Feature>/` (the protocol and entity
types) and `Core/Data/<Feature>/` (the `Real` and `Fake` implementations
plus the API client).

## Consequences

- **Positive.** Testability is first class — ViewModels are tested against
  fakes without touching the network. The dev and production experiences
  are identical, so a UI state that only appears with real data is caught
  during development, not after release. The protocol layer leaves room
  to swap implementations (e.g. a future SQLite cache, an on-device ML
  summariser) without touching feature code.
- **Negative.** Every new feature requires writing a protocol, a real
  implementation, a fake implementation for tests, and the DTO + mapping
  code. This is ceremony that a small project might skip; the project has
  decided the ceremony pays off.
- **Implementation rule.** If a developer is tempted to wire a fake
  repository into a non-test target for convenience, the correct move is
  to build out the skeleton / placeholder UI instead. Fakes never ship.
