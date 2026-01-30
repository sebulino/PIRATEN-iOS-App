# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

This is an Xcode project. Use `xcodebuild` from the command line:

```bash
# Build the app
xcodebuild -scheme PIRATEN -configuration Debug build

# Run unit tests
xcodebuild -scheme PIRATEN -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a specific test class
xcodebuild -scheme PIRATEN -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PIRATENTests/PIRATENTests test

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
