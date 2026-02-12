# PIRATEN iOS App

Unofficial iOS app for members of the Piratenpartei Deutschland.

## Overview

This is a native iOS app built with Swift and SwiftUI. It provides members access to:
- **Forum**: Discourse-based discussion forums
- **Messages**: Private messaging via Discourse
- **Knowledge**: Internal knowledge base
- **Todos**: Task management via meine-piraten.de
- **Profile**: User profile and settings

The app follows a **privacy-first** approach with no analytics or tracking.

## Current Status

| Feature | Status | Notes |
|---------|--------|-------|
| **SSO Login** | ✅ Implemented | Keycloak OAuth2/OIDC via AppAuth |
| **Token Management** | ✅ Implemented | Secure Keychain storage, auto-refresh |
| **Discourse Auth** | ✅ Implemented | User API Key flow (RSA encrypted) |
| **Forum (Topics)** | ✅ Read-only | Fetches from Discourse API |
| **Forum (Posts)** | ✅ Read-only | Topic detail with posts, tappable usernames |
| **Private Messages** | ✅ Read + Compose | Inbox, thread detail, compose with recipient picker |
| **User Profiles** | ✅ Implemented | Tappable usernames, direct messaging from profile |
| **Todos** | ✅ Stubbed (write) | Create, claim, complete, comment, detail view (fake data, awaiting meine-piraten.de API) |
| **Push Notifications** | ✅ Scaffolded | APNs token registration, deep links, backend contract documented |
| **Profile** | ✅ Implemented | SSO user info, notification preferences |
| **Knowledge** | 🚧 Placeholder | Not yet specified |
| **Posting/Replies** | ❌ Not started | Future milestone |

See [PROJECT_STATUS.md](Docs/PROJECT_STATUS.md) for detailed milestone progress.

## Requirements

- Xcode 16.0 or later
- iOS 18.0+ deployment target
- macOS 14.0+ for development

## Dependencies

The app uses Swift Package Manager for external dependencies:

| Package | Purpose |
|---------|---------|
| [AppAuth-iOS](https://github.com/openid/AppAuth-iOS) | OAuth2/OIDC authentication with PKCE support |

## Getting Started

### 1. Clone the repository

```bash
git clone <repository-url>
cd PIRATEN
```

### 2. Configure secrets

Copy the sample secrets file and fill in your values:

```bash
cp Config/Secrets.sample.xcconfig Config/Secrets.xcconfig
```

Edit `Config/Secrets.xcconfig` with the required values:

| Key | Description |
|-----|-------------|
| `SSO_CLIENT_ID` | OAuth2 client ID for Piratenlogin |
| `SSO_REDIRECT_URI` | OAuth callback URI (e.g., `piratenapp://callback`) |
| `DISCOURSE_CLIENT_ID` | Unique identifier for Discourse User API Key |
| `DISCOURSE_AUTH_REDIRECT_SCHEME` | URL scheme for Discourse auth callback |
| `DISCOURSE_AUTH_REDIRECT_HOST` | Host component for Discourse callback URL |
| `DISCOURSE_APP_NAME` | App name shown in Discourse when requesting API key |

**Note:** `Config/Secrets.xcconfig` is git-ignored and must never be committed.

### 3. Open in Xcode

```bash
open PIRATEN.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -scheme PIRATEN -configuration Debug build
```

### 4. Run in Simulator

Select a simulator in Xcode and press `Cmd+R`, or build from command line:

```bash
xcodebuild -scheme PIRATEN \
  -destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041' \
  build
```

## Build Commands

**Important:** Use UDID-based simulator destinations to prevent simulator clones (see [D-007](Docs/DECISIONS.md)).

```bash
# Build for simulator (pinned UDID)
xcodebuild -scheme PIRATEN \
  -destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041' \
  build

# Run unit tests
xcodebuild -scheme PIRATEN \
  -destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041' \
  test

# Run specific test class
xcodebuild -scheme PIRATEN \
  -destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041' \
  -only-testing:PIRATENTests/KeychainServiceTests \
  test

# Clean build artifacts
xcodebuild -scheme PIRATEN clean
```

If the pinned simulator UDID is unavailable after an Xcode update, run `xcrun simctl list devices available` and update the UDID.

## Authentication

The app uses a two-layer authentication system:

### 1. Keycloak SSO (Primary Login)
Users authenticate via the Piratenpartei SSO (Keycloak) using OAuth2/OIDC with PKCE. This is handled by AppAuth-iOS and provides the user's identity.

### 2. Discourse User API Key (Forum Access)
Discourse requires its own authentication. The app implements the [Discourse User API Keys specification](https://meta.discourse.org/t/user-api-keys-specification/48536):

```
┌─────────┐              ┌─────────┐              ┌───────────┐
│ iOS App │              │ Browser │              │ Discourse │
└────┬────┘              └────┬────┘              └─────┬─────┘
     │                        │                        │
     │ 1. Generate RSA key pair, store in Keychain     │
     │                        │                        │
     │ 2. Build auth URL with public key + nonce       │
     │───────────────────────>│                        │
     │    ASWebAuthSession    │ 3. Open URL            │
     │                        │───────────────────────>│
     │                        │                        │
     │                        │ 4. User logs in via SSO│
     │                        │<──────────────────────>│
     │                        │                        │
     │                        │ 5. User approves key   │
     │                        │<──────────────────────>│
     │                        │                        │
     │<───────────────────────│ 6. Encrypted callback  │
     │  Callback with RSA-encrypted API key            │
     │                        │                        │
     │ 7. Decrypt with private key                     │
     │ 8. Verify nonce (replay protection)             │
     │ 9. Store credential in Keychain                 │
     │                        │                        │
     │ 10. All API calls use User-Api-Key header       │
     │─────────────────────────────────────────────────>
```

**Security properties:**
- API key encrypted in transit (RSA)
- Private key never leaves device Keychain
- Nonce prevents replay attacks
- Scoped permissions (notifications, session_info)
- Revocable on logout

## Architecture

The app follows **Clean Architecture + MVVM**:

```
PIRATEN/
├── App/                    # Presentation layer
│   ├── Views/              # SwiftUI views (Forum, Messages, Todos, Profile)
│   ├── ViewModels/         # View models for each feature
│   ├── PIRATENApp.swift    # App entry point
│   └── RootView.swift      # Root navigation (login vs main)
├── Core/
│   ├── Domain/             # Business logic layer
│   │   ├── Auth/           # Auth entities, protocols, state machine
│   │   ├── DeepLink/       # Deep link routing from notifications
│   │   ├── Discourse/      # Forum/message entities, API key models
│   │   ├── HTTP/           # HTTP client protocol, request/response types
│   │   └── Todos/          # Todo entities, comments, and repository protocol
│   ├── Data/               # Data layer implementations
│   │   ├── Auth/           # OIDC auth repository
│   │   ├── Discourse/      # Discourse API client, auth manager
│   │   ├── HTTP/           # URLSession client, authenticated clients
│   │   ├── OIDC/           # AppAuth integration services
│   │   └── Todos/          # Todo repository (fake/in-memory)
│   └── Support/            # System wrappers
│       ├── AppContainer.swift    # Dependency injection root
│       ├── KeychainService.swift # Secure credential storage
│       └── RSAKeyManager.swift   # RSA key operations for Discourse auth
├── Config/                 # xcconfig files (Debug, Release, Secrets)
├── Resources/              # Assets, brand files
└── Docs/                   # Project documentation
```

See `CLAUDE.md` for detailed architecture rules.

## Documentation

- [Project Status](Docs/PROJECT_STATUS.md) - Current milestone and progress
- [Decisions](Docs/DECISIONS.md) - Architectural decisions and rationale
- [Open Questions](Docs/OPEN_QUESTIONS.md) - Unresolved questions blocking work
- [Threat Model](Docs/THREAT_MODEL.md) - Security considerations

## Contributing

1. Work on one milestone at a time
2. Follow the architecture rules in `CLAUDE.md`
3. Update documentation with every change
4. Run tests before committing

## License

Proprietary - Piratenpartei Deutschland
