# PIRATEN iOS App

Official iOS app for members of the Piratenpartei Deutschland.

## Overview

This is a native iOS app built with Swift and SwiftUI. It provides members access to:
- **Forum**: Discourse-based discussion forums
- **Messages**: Private messaging via Discourse
- **Knowledge**: Internal knowledge base
- **Todos**: Task management via meine-piraten.de
- **Profile**: User profile and settings

The app follows a **privacy-first** approach with no analytics or tracking.

## Requirements

- Xcode 16.0 or later
- iOS 18.0+ deployment target
- macOS 14.0+ for development

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

Edit `Config/Secrets.xcconfig` with actual values (see file for required keys).

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

Select a simulator in Xcode and press `Cmd+R`, or:

```bash
xcodebuild -scheme PIRATEN -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Build Commands

```bash
# Build for simulator
xcodebuild -scheme PIRATEN -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run unit tests
xcodebuild -scheme PIRATEN -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run specific test class
xcodebuild -scheme PIRATEN -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PIRATENTests/KeychainServiceTests test

# Clean build artifacts
xcodebuild -scheme PIRATEN clean
```

## Architecture

The app follows **Clean Architecture + MVVM**:

```
PIRATEN/
├── App/              # App entry point, views, view models
│   ├── Views/        # SwiftUI views
│   └── RootView.swift
├── Core/             # Domain layer
│   ├── Domain/       # Entities, use cases, protocols
│   └── Support/      # System wrappers (Keychain, etc.)
├── Features/         # Feature modules (future)
└── Resources/        # Assets, localization
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
