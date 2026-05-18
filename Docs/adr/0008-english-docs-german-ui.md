# ADR-0008 — English documentation, German user interface

- **Status:** Accepted
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** NFR-002

## Context

The app's user base is exclusively German-speaking members of the
Piratenpartei Deutschland. The UI must therefore be German. The contributor
base benefits from being as broad as possible: contributors may come from
the broader international Free-Software community, may be working with AI
coding assistants that perform better in English, and may include future
maintainers who do not read German.

Mixed-language documentation ("some ADRs in German, some in English, code
comments in whichever language the author woke up feeling") accumulates
friction over time.

## Decision

- **Documentation, ADRs, code comments, commit messages, branch names, and
  PR titles/descriptions are in English.**
- **User-facing strings (UI copy, help text inside the app) are in German.**
  In v1 these strings are hardcoded German literals — there is no
  `Localizable.strings` file, no `String(localized:)`, no i18n scaffolding.
  **Internationalisation is planned for a post-v1 release.**
- Party-specific terms stay in German across both worlds — `Kajüte`,
  `Pirat`, `Vorstand`, `Landesverband`, `GMM` — and are defined in
  [`glossary.md`](../glossary.md).

## Consequences

- **Positive.** Contributor pool is broad; the user-facing product is native.
  Ship velocity is not paid for up front on i18n infrastructure that would
  not serve any user in v1.
- **Negative.** Adding a second language post-v1 will require a focused
  refactor: every German string currently in a SwiftUI view must move into
  `Localizable.strings` (or `.xcstrings`). The repository pattern and the
  relatively small view surface keep this tractable, but it is not free.
- **Contributor rule.** PRs that violate the English-code / German-UI rule
  are redirected, not rejected: a maintainer translates the offending parts
  and lands the change.
