# Integrations — MeinePIRATEN iOS

Each external system the app talks to, and the contract the app relies on.
When any of these change, this document changes with them.

All base URLs are configured via `Config/Secrets.xcconfig` (gitignored) and
read from `Info.plist` at build time. A sample configuration with placeholder
values is provided at `Config/Secrets.sample.xcconfig`.

A single PiratenSSO realm and a single Discourse host are used for dev,
staging and production. Tests use stubs and never hit live infrastructure.

---

## 1. PiratenSSO

- **Protocol:** OIDC / OAuth 2.0.
- **Flow:** Authorisation Code with PKCE, via `ASWebAuthenticationSession`
  (through the AppAuth-iOS library).
- **Implementation:** The identity provider is Keycloak. The abstraction
  "PiratenSSO" is preserved in the ADRs so the underlying technology could
  change without renaming concepts; the Keycloak specifics live here and in
  `Secrets.xcconfig`.
- **Base URL:** `KEYCLOAK_BASE_URL` (current value:
  `https://sso.piratenpartei.de/realms/Piratenlogin`)
- **Scopes:** `openid profile email`
- **Tokens:** access + refresh + ID token. All stored in the Keychain with
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- **Client registration:** client ID and redirect URI come from
  `Config/Secrets.xcconfig`. A sample is provided in
  `Config/Secrets.sample.xcconfig`.
- **Endpoints called:**
  - `GET /.well-known/openid-configuration` — discovery
  - Browser authorise (opaque to the app)
  - `POST /protocol/openid-connect/token` — code exchange, refresh

See [ADR-0003](./adr/0003-piratensso-as-sole-identity-provider.md).

---

## 2. Discourse

Discourse is the **backend of record** for forum content, private messages,
likes and notifications ([ADR-0002](./adr/0002-discourse-as-backend-of-record.md)).

### 2.1 Base URL and authentication

- **Base URL:** `DISCOURSE_BASE_URL` (current value:
  `https://diskussion.piratenpartei.de`)
- **Auth:** User API Key, obtained via the `/user-api-key/new` handshake
  (see [ADR-0009](./adr/0009-discourse-user-api-key.md)).
  Injected by `DiscourseHTTPClient` as the `User-Api-Key` header on every
  authenticated request.

### 2.2 Endpoints the app depends on

| Purpose | Endpoint |
|---|---|
| Authenticated identity | `GET /session/current.json` |
| List latest / category topics | `GET /latest.json`, `GET /c/{slug}/{id}.json` |
| Read a topic with posts | `GET /t/{id}.json`, `GET /t/{id}/posts.json` |
| Post a reply | `POST /posts.json` |
| Create a new topic | `POST /posts.json` with `title` + `category` |
| Like a post | `POST /post_actions.json` — **currently not syncing** ([OPEN-02](./open-issues.md)) |
| List user messages | `GET /topics/private-messages/{user}.json`, `GET /topics/private-messages-sent/{user}.json` |
| Read user profile | `GET /users/{user}.json` |
| User search (DM recipient picker) | `GET /u/search/users.json` |
| Mark topic read | `POST /topics/timings` |
| Notifications totals | `GET /notifications/totals.json` |

### 2.3 Caveats the app must respect

- **Rate limits.** Discourse enforces per-IP and per-user rate limits. The
  `HTTPClient` must back off on 429 and surface a user-facing "try again in a
  moment" state, never hammer.
- **Likes are unsolved.** Posting `POST /post_actions.json` from the app
  currently does not propagate to the Discourse server. Prior investigation
  of the official Discourse mobile app yielded no insights; following the
  API docs did not produce results. [OPEN-02](./open-issues.md) must be
  resolved before v1 ship.
- **Read state.** The app calls `/topics/timings` when a user reads a topic
  so other devices / the web UI stay in sync.
- **Notifications.** Foreground polls `/notifications/totals.json` every
  60 seconds; background BGAppRefreshTask polls every 30 minutes.

---

## 3. Agitatorrr (events)

- **Base URL:** `AGITATORRR_BASE_URL` (current value: `https://agitatorrr.de`)
- **Endpoint:** `GET /api/veranstaltung/ical`
- **Auth:** public, no auth.
- **Format:** iCalendar (RFC 5545) — parsed by the app's hand-rolled
  `ICalParser.swift` ([ADR-0013](./adr/0013-minimal-third-party-dependencies.md)).
- **Naming note.** Internally and historically also referred to as
  "Piragitator"; `agitatorrr.de` is the canonical public-facing domain.
- **Failure mode.** If unreachable, the Termine tab shows the cached last
  response with a "last updated" timestamp and a retry affordance.

---

## 4. meine-piraten.de

Maintained by the party's ops team. Full API documentation at
<https://meine-piraten.de/api>.

- **Base URL:** `MEINE_PIRATEN_BASE_URL` (current value:
  `https://meine-piraten.de`)
- **Format:** JSON — append `.json` to any endpoint or send `Accept: application/json`.

### 4.1 News (public)

| Method | Path | Auth |
|---|---|---|
| `GET` | `/api/news.json?limit={n}` (max 200, default 50) | Public |

Response: array of `{ chat_id, message_id, posted_at, text }`. Posts come
from a Telegram channel bridge maintained by the backend — the app does not
interact with Telegram directly and does not hold a Telegram bot token.

### 4.2 ToDos

Auth: PiratenSSO JWT bearer token (`Authorization: Bearer <access_token>`).

| Method | Path | Auth level |
|---|---|---|
| `GET` | `/tasks.json` | Any authenticated user |
| `GET` | `/tasks/{id}.json` | Any authenticated user |
| `POST` | `/tasks.json` | Admin |
| `PATCH` | `/tasks/{id}.json` | Any user (fields restricted for non-admins) |
| `DELETE` | `/tasks/{id}.json` | Admin |
| `GET` | `/tasks/{id}/comments.json` | Any authenticated user |
| `POST` | `/tasks/{id}/comments.json` | Any authenticated user |
| `GET` | `/entities.json` | Any authenticated user |
| `GET` | `/categories.json` | Any authenticated user |

**Status state machine:**

```
open ──► claimed ──► completed ──► done (terminal)
  ▲         │
  └─────────┘  (release)
```

Non-admin users may transition `open → claimed → completed` and
`claimed → open`. The `completed → done` transition is admin-only.

**401 handling:** mapped to `TodoError.unauthorized` and triggers
`AuthStateManager.logout()`.

### 4.3 Admin requests

Auth: PiratenSSO JWT bearer token.

| Method | Path | Auth level |
|---|---|---|
| `GET` | `/admin_requests/status.json` | Any authenticated user |
| `POST` | `/admin_requests.json` | Any authenticated user |
| `PATCH` | `/admin_requests/{id}/approve.json` | Superadmin |
| `PATCH` | `/admin_requests/{id}/reject.json` | Superadmin |
| `PATCH` | `/admin_requests/{id}/demote.json` | Superadmin |

Used by the in-app admin request form (FR-PROF-007). The approve / reject /
demote endpoints are not exposed in the app.

### 4.4 Endpoints the app does NOT use

- `/api/messages` — private messaging on meine-piraten.de. The app uses
  Discourse PMs instead (FR-MSG-*).
- `/api/push_subscriptions` — APNs push relay. The app uses polling only
  (ADR-0006).

---

## 5. GitHub — PIRATEN-Kanon

- **Repository:** <https://github.com/sebulino/PIRATEN-Kanon> (intended
  future home: `piratenpartei` organisation, tracked in [OPEN-10](./open-issues.md))
- **Config keys:** `KNOWLEDGE_REPO_OWNER`, `KNOWLEDGE_REPO_NAME`,
  `KNOWLEDGE_REPO_BRANCH`
- **Endpoint:** `GET https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={branch}`
  — returns JSON listing; blobs are Base64-encoded in the response.
- **Auth:** none (anonymous). Subject to GitHub's 60 req/h/IP limit for
  unauthenticated requests. Accepted for v1 — revisited if it becomes a
  user-visible problem.
- **Update model:** The app stores the commit SHA of the last successfully
  downloaded Kanon content. On startup it queries the latest remote SHA;
  if it differs from the stored SHA, new content is downloaded and cached.
  If GitHub is unreachable, the locally cached content is used. No
  per-app-release pinning, no bundled fallback. See [ADR-0011](./adr/0011-kanon-sha-tracking.md).
- **Authoring:** A schema document for external Kanon authors is tracked in
  [OPEN-11](./open-issues.md).

---

## 6. Summary: failure isolation

Each upstream has an independent cache, an independent refresh cadence, and
fails independently. Losing one upstream degrades exactly one tab, not the
app (NFR-005).
