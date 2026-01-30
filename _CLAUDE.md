# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

This is an Xcode project. Use `xcodebuild` from the command line.

**IMPORTANT:** Use UDID-based simulator destinations to prevent clone creation.
See `Docs/DECISIONS.md` (D-007) for rationale and fallback procedure.

```bash
# Build the app (simulator)
xcodebuild -scheme PIRATEN -destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041' build

# Run unit tests (pinned simulator UDID - iPhone 16, iOS 26.2)
xcodebuild -scheme PIRATEN -destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041' test

# Run a specific test class
xcodebuild -scheme PIRATEN -destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041' -only-testing:PIRATENTests/PIRATENTests test

# Clean build
xcodebuild -scheme PIRATEN clean
```

## Architecture

**Stack**: SwiftUI + SwiftData (iOS 17+)

**Key Files**:
- `PIRATEN/PIRATENApp.swift` - App entry point, configures SwiftData ModelContainer
- `PIRATEN/ContentView.swift` - Main UI view with NavigationSplitView
- `PIRATEN/Item.swift` - SwiftData model using `@Model` macro

**Data Flow**:
- SwiftData handles persistence via `ModelContainer` injected at app level
- Views query data using `@Query` property wrapper
- Mutations happen through `@Environment(\.modelContext)`

**Test Targets**:
- `PIRATENTests/` - Unit tests using Apple's Testing framework
- `PIRATENUITests/` - UI tests using XCTest
