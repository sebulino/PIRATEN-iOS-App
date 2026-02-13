# CI/CD Notes

This document describes the build and test commands used by both the Ralph autonomous agent and local developers.

Last updated: 2026-02-13

---

## Prerequisites

- **Xcode**: Latest version with iOS 26.x SDK (currently Xcode 26.x)
- **Command Line Tools**: `xcode-select --install`
- **Simulator**: iPhone 16 (iOS 26.2) must be available
- **Secrets**: `Config/Secrets.xcconfig` must exist (copy from `Config/Secrets.sample.xcconfig`)

---

## Simulator Destination

All automated commands use a **pinned simulator UDID** to prevent Xcode from creating simulator clones (see D-007 in DECISIONS.md):

```
platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041
```

This targets: **iPhone 16, iOS 26.2**

### If the simulator UDID becomes invalid

After an Xcode update, the UDID may change. To find a replacement:

```bash
xcrun simctl list devices available | grep iPhone
```

Pick an iPhone 16 (or similar) UDID from the latest iOS runtime and update:
1. This file
2. `CLAUDE.md` (section 13)
3. `Docs/DECISIONS.md` (D-007)

---

## Build Commands

### Debug build (simulator)

```bash
xcodebuild -scheme PIRATEN \
  -destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041' \
  build
```

### Release build (generic iOS device)

```bash
xcodebuild -scheme PIRATEN \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  build
```

### Clean build

```bash
xcodebuild -scheme PIRATEN clean
```

---

## Test Commands

### Run all tests

```bash
xcodebuild -scheme PIRATEN \
  -destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041' \
  test
```

### Run a specific test class

```bash
xcodebuild -scheme PIRATEN \
  -destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041' \
  -only-testing:PIRATENTests/SpecificTestClass \
  test
```

---

## Archive & Export (Release)

### Create archive

```bash
xcodebuild archive \
  -scheme PIRATEN \
  -destination 'generic/platform=iOS' \
  -archivePath './build/PIRATEN.xcarchive'
```

### Export for App Store

```bash
xcodebuild -exportArchive \
  -archivePath './build/PIRATEN.xcarchive' \
  -exportPath './build/Export' \
  -exportOptionsPlist ExportOptions.plist
```

> **Note:** `ExportOptions.plist` must be created with the appropriate distribution method (`app-store`, `ad-hoc`, or `development`) and team ID. This file is not committed to the repository as it contains team-specific signing information.

---

## Ralph Agent Usage

The Ralph autonomous agent runs inside a loop (`scripts/ralph/`) and uses the following workflow per iteration:

1. **Read** `scripts/ralph/prd.json` to find the next incomplete story
2. **Implement** the story
3. **Build** using the debug build command above
4. **Test** if the story requires tests
5. **Commit** on success with message format: `feat: [Story ID] - [Story Title]`

Ralph uses the pinned simulator UDID from CLAUDE.md section 13.

---

## Configuration Files

| File | Role | Committed |
|------|------|-----------|
| `Config/Debug.xcconfig` | Dev environment settings (URLs, bundle ID) | Yes |
| `Config/Release.xcconfig` | Production environment settings | Yes |
| `Config/Secrets.xcconfig` | Local secrets (SSO keys, optional overrides) | **No** |
| `Config/Secrets.sample.xcconfig` | Template showing required secret keys | Yes |

### Setting up secrets for a new developer

```bash
cp Config/Secrets.sample.xcconfig Config/Secrets.xcconfig
# Edit Secrets.xcconfig with actual values
```

The `Secrets.xcconfig` is included by both `Debug.xcconfig` and `Release.xcconfig` via `#include "Secrets.xcconfig"`. Values in `Secrets.xcconfig` override the defaults in the environment-specific configs.

---

## Sensitive Config via xcconfig

All sensitive or environment-specific values are injected through `.xcconfig` files, **never hardcoded**:

| Value | Config Key | Default Location |
|-------|-----------|-----------------|
| SSO Client ID | `SSO_CLIENT_ID` | Secrets.xcconfig |
| SSO Redirect URI | `SSO_REDIRECT_URI` | Secrets.xcconfig |
| Discourse Base URL | `DISCOURSE_BASE_URL` | Debug/Release.xcconfig |
| Discourse Client ID | `DISCOURSE_CLIENT_ID` | Debug/Release.xcconfig |
| Discourse Auth Redirect | `DISCOURSE_AUTH_REDIRECT_SCHEME` | Debug/Release.xcconfig |
| meine-piraten.de URL | `MEINE_PIRATEN_BASE_URL` | Debug/Release.xcconfig |
| Knowledge Repo Owner | `KNOWLEDGE_REPO_OWNER` | Debug/Release.xcconfig |
| Knowledge Repo Name | `KNOWLEDGE_REPO_NAME` | Debug/Release.xcconfig |

These are exposed to the app at runtime via `Info.plist` variable expansion (e.g., `$(DISCOURSE_BASE_URL)`).
