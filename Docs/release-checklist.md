# Release Checklist

Used before pushing a new build to TestFlight or the App Store. Not every
item applies to every release; cross out what does not.

> **Note.** The marketing version is stuck at `1.0` as a legacy artefact.
> The build number is the authoritative version indicator.

---

## Before the build

### Code

- [ ] All CI checks pass on the release branch (build + tests + SwiftLint + SwiftFormat).
- [ ] No new `print(...)` calls outside `#if DEBUG`.
- [ ] `Fake<Feature>Repository` implementations are wired only in
      `PIRATENTests/`, nowhere in the running app.
- [ ] `LogRedactor` is applied at every log site that could contain user
      data or tokens.
- [ ] No new third-party dependencies have been added without an ADR.
- [ ] `Config/Secrets.xcconfig` is filled with production values and is
      **not** committed. `Config/Secrets.sample.xcconfig` is up to date.

### Documentation

- [ ] `README.md` reflects the actual implemented feature set (no stale
      "not started" claims).
- [ ] `docs/requirements.md` matches the shipped functionality.
- [ ] Any new decisions have ADR entries.
- [ ] `docs/open-issues.md` lists only items that remain open; resolved
      items are crossed out with a pointer to the ADR or Q-decision.

### Secrets and configuration

- [ ] PiratenSSO client ID and redirect URI are correct for the build
      target.
- [ ] Discourse base URL is `https://diskussion.piratenpartei.de`.
- [ ] Knowledge repo owner/name/branch points at the intended source.
- [ ] No Telegram tokens or other non-app secrets in `Secrets.xcconfig`.

---

## Pre-v1 release blockers

Items that must be resolved before the first v1 TestFlight build:

- [ ] **OPEN-02** — Likes sync to Discourse end-to-end (FR-FORUM-004).
- [ ] **OPEN-09** — `handleAuthenticationError()` has a defined behaviour
      and is no longer inert.
- [ ] **OPEN-12** — `BGAppRefreshTask` dispatches local iOS notifications
      for enabled categories (FR-NOTIF-004).
- [ ] **OPEN-06** — CI pipeline exists and passes on the release branch.

---

## Acceptance smoke test

Run on a real device, on cellular (not Wi-Fi), with the app freshly
reinstalled. Verify each in order:

- [ ] Launch the app. Log in via PiratenSSO. Land on a populated Kajüte.
- [ ] Open the Forum tab. Scroll. Open a topic. Post a reply. See the
      reply on Discourse in a browser.
- [ ] Like a post. Open the same post on Discourse web — the like is
      visible and attributed to you.
- [ ] Send a new DM. The recipient picker returns real Discourse users.
- [ ] Open the Wissen tab. Read a Kanon entry. Take its quiz. See the
      score.
- [ ] Open the Termine tab. Tap an event. Tap "Add to Calendar" and
      confirm it lands in iOS Calendar.
- [ ] Open the ToDos tab. Claim a task. Confirm it appears on the Kajüte
      under "Übernommene Aufgaben". Release it. Confirm it returns to the
      open list.
- [ ] Open the News tab. Tap a card. Source URL opens in
      `SFSafariViewController`.
- [ ] Background the app. Wait long enough for a `BGAppRefreshTask` to
      fire (may require a physical device and iOS's own scheduling). If a
      new item exists in an enabled category, a banner appears on the lock
      screen.
- [ ] Turn off the network. Re-open the app. Cached content renders.

---

## Post-release

- [ ] Tag the release commit in Git (`v0.X-build-YY` or similar).
- [ ] Update `README.md` if any feature status changed.
- [ ] Monitor for crash reports or error feedback from testers (informal
      in v1; formal crash reporting is deferred to post-v1).
