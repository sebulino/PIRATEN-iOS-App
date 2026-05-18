# MeinePIRATEN

An unofficial iOS app for members of the **Piratenpartei Deutschland**.

## Why this app exists

The party's digital life is fragmented: Discourse for discussion, meine-piraten.de
for tasks and news, Agitatorrr for events, a GitHub-backed Kanon for internal
knowledge, and — for most members — Telegram as the place where things
actually happen. MeinePIRATEN bundles the member-facing pieces into one
mobile client with a Telegram-adjacent feel, so that reading the forum, replying
to a DM, claiming a todo, or checking the next event takes one tap instead of
five apps.

Discourse remains the **backend of record** for all discussion; this app is a
thin client, not a parallel data store. No analytics, no tracking, no copies of
anything that isn't already on a server the party controls.

- **Platform:** iOS only
- **Minimum iOS:** 26.2
- **UI language:** German
- **Code, docs, commits:** English

## Features

Be aware that this project is a work in progress. The list below reflects what
is currently in `main`.

| Area | What works today | Not yet |
|---|---|---|
| **Kajüte** (home) | Greeting, recent contacts, in-progress Kanon articles ("weiterlesen"), übernommene Aufgaben, feedback widget | — |
| **Forum** | List topics, read threads, reply, like, read-state tracking | Category pins, new-topic creation, inline images |
| **Wissen** (Kanon) | GitHub-hosted lessons, offline cache, quizzes, reading-progress tracking | — |
| **Termine** | Events from the Agitatorrr iCal feed, upcoming & past sections | EventKit integration ("add to calendar") |
| **ToDos** | List, claim, complete, release, comment — against meine-piraten.de | — |
| **Nachrichten** | Inbox, thread detail, reply, compose new DM via recipient picker | — |
| **News** | Feed from `meine-piraten.de/api/news` with detail view | — |
| **Profil** | SSO user info, notification toggles, feedback submission, admin-access request, logout | — |

## Getting started

### Prerequisites

- A recent Xcode with iOS 26.2 SDK
- An iOS 26.2 simulator or device
- Piratenpartei membership (SSO login is required for most features)

### 1. Clone

```bash
git clone <repository-url>
cd PIRATEN
```

### 2. Create your local secrets file

```bash
cp Config/Secrets.sample.xcconfig Config/Secrets.xcconfig
```

`Config/Secrets.xcconfig` is git-ignored and must never be committed.

### 3. Fill in real values

Edit `Config/Secrets.xcconfig`:

| Key | Description |
|-----|-------------|
| `SSO_CLIENT_ID` | OAuth2 client ID registered with PiratenSSO (Keycloak) |
| `SSO_REDIRECT_URI` | OAuth callback URI for the app's custom URL scheme |
| `KEYCLOAK_BASE_URL` | Keycloak realm base URL for PiratenSSO |
| `DISCOURSE_BASE_URL` | Base URL of the Discourse forum |
| `DISCOURSE_CLIENT_ID` | Client identifier used when requesting a Discourse User API Key |
| `DISCOURSE_AUTH_REDIRECT_SCHEME` | URL scheme for the Discourse auth callback |
| `DISCOURSE_AUTH_REDIRECT_HOST` | Host component for the Discourse callback URL |
| `DISCOURSE_APP_NAME` | App name shown to the user during Discourse auth |
| `KNOWLEDGE_REPO_OWNER` | GitHub owner of the PIRATEN-Kanon repository |
| `KNOWLEDGE_REPO_NAME` | GitHub repository name for the Kanon |
| `KNOWLEDGE_REPO_BRANCH` | Branch of the Kanon repository to pull from |
| `MEINE_PIRATEN_BASE_URL` | Base URL of the meine-piraten.de backend |
| `AGITATORRR_BASE_URL` | Base URL of the Agitatorrr events/calendar service |

### 4. Build and run

Open `PIRATEN.xcodeproj` in Xcode, select the **PIRATEN** scheme and an iOS 26.2
destination, then press Run.

Command line:

```bash
xcodebuild -scheme PIRATEN \
  -destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041' \
  build
```

## Architecture overview

Clean Architecture + MVVM with strict layer separation: SwiftUI views + view
models in `PIRATEN/App/`, domain entities and repository protocols in
`PIRATEN/Core/Domain/`, API clients and repository implementations in
`PIRATEN/Core/Data/`, system wrappers (Keychain, config, background tasks) in
`PIRATEN/Core/Support/`. Dependencies are wired exclusively through
`AppContainer` via constructor injection — no hidden singletons, no globals
inside features.

See `CLAUDE.md` for the full architectural rulebook and `Docs/DECISIONS.md` for
the reasoning behind individual choices.

## Documentation

Engineering documentation lives in [`Docs/`](Docs/README.md) — start there for
the index of project status, decisions, open questions, threat model, API
request map, and release checklists.

## Contributing

- Code, documentation, and commit messages are in **English**; UI strings are in
  **German**.
- Every PR must build cleanly and pass the existing test suite (`xcodebuild …
  test`).
- A full `CONTRIBUTING.md` is coming soon; until then, follow the rules in
  `CLAUDE.md` and the patterns visible in the codebase.

## Versioning

Marketing version `1.0` is a legacy artefact from the initial project setup and
does not track releases. The real counter is the **build number**
(`CURRENT_PROJECT_VERSION`, currently **17**), which is incremented for every
TestFlight / App Store build.

## Licence

MeinePIRATEN is released under the **EUPL-1.2** (European Union Public Licence,
version 1.2).
