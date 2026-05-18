# Architecture Decision Records

Short records of decisions that shape the app. We use the **Michael Nygard**
format: Context → Decision → Consequences. Each ADR is immutable once
*Accepted*; to change a decision, write a new ADR that supersedes it.

Statuses: `Proposed` · `Accepted` · `Superseded by ADR-xxxx` · `Deprecated`.

## Index

| # | Title | Status |
|---|---|---|
| [0001](./0001-native-swiftui-app.md) | Native SwiftUI app on iOS (26.2+, iPhone only) | Accepted |
| [0002](./0002-discourse-as-backend-of-record.md) | Discourse is the backend of record | Accepted |
| [0003](./0003-piratensso-as-sole-identity-provider.md) | PiratenSSO is the sole identity provider | Accepted |
| [0004](./0004-no-app-specific-backend-v1.md) | No app-specific backend in v1 | Accepted |
| [0005](./0005-offline-first-cache.md) | Offline-first cache with SQLite / GRDB | Superseded by ADR-0010 |
| [0006](./0006-notifications-v1-polling.md) | Polling-based notifications with local banner dispatch | Accepted |
| [0007](./0007-kanon-pinned-by-commit.md) | Kanon is pinned to a commit per release | Superseded by ADR-0011 |
| [0008](./0008-english-docs-german-ui.md) | English docs, German UI (i18n deferred to post-v1) | Accepted |
| [0009](./0009-discourse-user-api-key.md) | Discourse authentication via User API Key | Accepted |
| [0010](./0010-v1-cache-in-userdefaults-and-filesystem.md) | v1 cache in UserDefaults and filesystem | Accepted |
| [0011](./0011-kanon-sha-tracking.md) | Kanon SHA tracking | Accepted |
| [0012](./0012-repository-pattern-real-fake-split.md) | Repository pattern with Real / Fake split | Accepted |
| [0013](./0013-minimal-third-party-dependencies.md) | Minimal third-party dependencies | Accepted |
