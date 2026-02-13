# Release Checklist

This document defines the minimal, repeatable steps required before submitting the PIRATEN iOS app for distribution.

Last updated: 2026-02-13

---

## 1. Versioning

The app uses standard Apple version fields in the Xcode project:

| Field | Build Setting | Current | Purpose |
|-------|---------------|---------|---------|
| Marketing version | `MARKETING_VERSION` | 1.0 | User-visible version (e.g. 1.0, 1.1) |
| Build number | `CURRENT_PROJECT_VERSION` | 1 | Incrementing integer per submission |

**Before each release:**
1. Bump `MARKETING_VERSION` if the release contains user-visible changes
2. Always increment `CURRENT_PROJECT_VERSION` (App Store requires unique build numbers)
3. Update both in the Xcode project settings (Build Settings → Versioning)

---

## 2. Code Signing

| Setting | Value |
|---------|-------|
| Signing style | Automatic (`CODE_SIGN_STYLE = Automatic`) |
| Team | Must be set to the Piratenpartei Apple Developer account |
| Bundle ID (Release) | `de.piratenpartei.app` (set via `Release.xcconfig`) |
| Bundle ID (Debug) | `de.piratenpartei.app.debug` (set via `Debug.xcconfig`) |

**Before each release:**
1. Confirm the Apple Developer Team is selected in Xcode → Signing & Capabilities
2. Ensure a valid Distribution provisioning profile exists for `de.piratenpartei.app`
3. Verify entitlements match capabilities (currently: none beyond default)

---

## 3. Configuration & Secrets

All environment-specific configuration lives in `.xcconfig` files:

| File | Purpose | Committed? |
|------|---------|------------|
| `Config/Debug.xcconfig` | Dev URLs, debug bundle ID | Yes |
| `Config/Release.xcconfig` | Production URLs, release bundle ID | Yes |
| `Config/Secrets.xcconfig` | Local overrides (SSO keys, API keys) | **No** (git-ignored) |
| `Config/Secrets.sample.xcconfig` | Template for secrets | Yes |

**Before each release:**
1. Verify `Config/Secrets.xcconfig` is listed in `.gitignore`
2. Run `git diff --cached --name-only` to confirm no secrets are staged
3. Verify `Secrets.sample.xcconfig` documents all required keys
4. Confirm `Release.xcconfig` URLs point to production endpoints

---

## 4. Privacy Review

The app follows a strict no-analytics, no-tracking policy (see D-005 in DECISIONS.md).

**Before each release:**
1. Confirm no analytics or tracking SDKs have been added
2. Review App Store privacy nutrition labels — the app:
   - Does NOT collect any data for tracking
   - Collects data linked to identity only for app functionality (authentication)
3. Verify the in-app privacy page (Settings → Datenschutz) is accurate
4. If Apple requires a Privacy Manifest (`PrivacyInfo.xcprivacy`):
   - Declare required reason APIs used (e.g., `UserDefaults`, file timestamp APIs)
   - Declare no tracking domains
5. Verify no PII is logged (see THREAT_MODEL.md, M9-001 audit)

---

## 5. Build & Test

```bash
# Clean build for release configuration
xcodebuild clean build \
  -scheme PIRATEN \
  -configuration Release \
  -destination 'generic/platform=iOS'

# Run unit tests
xcodebuild test \
  -scheme PIRATEN \
  -destination 'platform=iOS Simulator,id=F0291949-CCB9-4C91-B947-292F98247041'

# Archive for distribution
xcodebuild archive \
  -scheme PIRATEN \
  -destination 'generic/platform=iOS' \
  -archivePath './build/PIRATEN.xcarchive'

# Export for App Store upload
xcodebuild -exportArchive \
  -archivePath './build/PIRATEN.xcarchive' \
  -exportPath './build/Export' \
  -exportOptionsPlist ExportOptions.plist
```

**Before each release:**
1. All unit tests pass
2. Release configuration builds without warnings (or warnings are documented)
3. Archive succeeds
4. Manual smoke test on a real device or simulator:
   - App launches
   - SSO login flow completes
   - Forum, Messages, Todos, Knowledge tabs load
   - Profile displays correctly

---

## 6. App Store Submission

1. Upload archive via Xcode Organizer or `xcrun altool` / Transporter
2. Fill in release notes in App Store Connect
3. Submit for review
4. Monitor review status

---

## 7. Post-Release

1. Tag the release commit: `git tag v<MARKETING_VERSION>-<BUILD_NUMBER>`
2. Update `Docs/PROJECT_STATUS.md` with release date
3. Archive any resolved open questions from `Docs/OPEN_QUESTIONS.md`
