## Summary

<!-- 1–3 sentences: what does this PR do and why? -->

## Related issue or requirement

<!-- e.g. Fixes #123, Implements FR-FORUM-008, Refs ADR-0007 -->

-

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Refactor (no behaviour change)
- [ ] Documentation
- [ ] Chore (build, tooling, dependencies, CI)

## Testing

<!-- What did you test, and how? Unit tests, simulator runs, device testing, manual steps. -->

-

## Checklist

- [ ] Code is in English (comments, identifiers, commit messages)
- [ ] UI strings are in German
- [ ] New features have a corresponding `Fake*` repository implementation for tests
- [ ] `LogRedactor` is used for any log messages containing user data or tokens
- [ ] No new force-unwraps introduced in non-trivial paths
- [ ] No new third-party dependencies without a justification in an ADR
- [ ] `xcodebuild … build` and `xcodebuild … test` pass locally
