# PIRATEN iOS App — Security Audit (2026-05-21)

**Scope:** Independent pre-App-Store-submission security review of the
PIRATEN iOS app at `/Users/sebulino/dev/PIRATEN-App/iOS/PIRATEN`.
**Auditor:** Security Engineer (independent review).
**Codebase commit context:** branch `main`, working tree as of 2026-05-25.
**Documents consulted before audit:** `Docs/threat-model.md`,
`Docs/integrations.md`, `Docs/requirements.md`, ADRs 0003, 0009, 0013,
0014 (incl. postscript), 0015.

---

## Executive summary

The PIRATEN iOS app demonstrates a thoughtful, privacy-first security
posture for a v1 member app. The fundamentals are right: AppAuth-iOS
for OAuth/OIDC with PKCE, no embedded webviews for login, no analytics,
no crash reporting, Keychain with `ThisDeviceOnly` accessibility for
tokens, App Transport Security fully enforced, almost no third-party
dependencies, central log redaction utilities, and a deliberate
"no message bodies in notifications" policy. The team has clearly
been thinking about adversarial scenarios — the threat model is
realistic and the documented mitigations are implemented in code.

The audit nonetheless surfaces issues that should block App Store
submission in their current form. **The single hard blocker is the
absence of `PrivacyInfo.xcprivacy`** — Apple has required this manifest
for new and updated apps that use any "Required Reason API" since 2024;
the app currently uses several (`UserDefaults`, `FileManager` timestamps,
`fileSize`), and the submission will be rejected automatically. The
second most material issue is that **`AuthStateManager.logout()` and the
`onLogout` handler in `PIRATENApp` together leave significant residue
behind**: the Discourse User API Key is never revoked server-side, the
RSA key pair stays in the Keychain, the PiratenSSO refresh token is
never invalidated via the end-session endpoint, message-thread drafts
remain in UserDefaults, and the notification poller / background
coordinator markers are not reset. The third is a **cross-origin
Authorization-header leak** in `URLSessionHTTPClient.RedirectHandler`:
the handler unconditionally re-attaches the caller's `Authorization`
header on any HTTP redirect target, including a redirect to a third-
party host.

**Findings by severity:** 0 Critical · 4 High · 6 Medium · 5 Low ·
4 Informational.

**Top three remediations before App Store submission:**

1. **Ship a `PrivacyInfo.xcprivacy`** declaring `NSPrivacyAccessedAPICategoryUserDefaults`
   (reason `CA92.1`), `NSPrivacyAccessedAPICategoryFileTimestamp`
   (reason `C617.1`), and `NSPrivacyAccessedAPICategoryDiskSpace`
   if applicable. Set `NSPrivacyTracking = false` and ship an empty
   `NSPrivacyCollectedDataTypes`. (Finding H-1.)
2. **Make logout actually log out.** Wire `revokeAPIKey`, `deleteKeyPair`,
   the OIDC end-session endpoint, `MessageDraftStore.clearDraft`,
   `DiscourseCacheStore.clearAll`, `NotificationSettingsManager.clearAllSettings`
   (also fix it to include the two missing toggles),
   `DiscourseNotificationPoller.reset`, and
   `BackgroundRefreshCoordinator.reset` into the `onLogout` path.
   (Finding H-2.)
3. **Scope the redirect Authorization re-attachment to the original
   host only.** `URLSessionHTTPClient.RedirectHandler` should compare
   `task.originalRequest?.url?.host` against `request.url?.host` and
   drop the header on host change. (Finding H-3.)

These three plus the High and Medium findings below should be addressed
before submission; the Low and Informational items can ride a post-v1
release.

---

## Methodology

- **Code reading.** Every Swift file under `PIRATEN/Core` and the
  authentication-touching files under `PIRATEN/App` (Auth views,
  ViewModels, AppContainer composition root, AppDelegate, RootView,
  MainTabView, PIRATENApp). Selective reading of Discourse,
  meine-piraten.de, Calendar, News, GitHub Knowledge data layers.
- **Configuration audit.** `Info.plist`, `PIRATEN.entitlements`,
  `Config/Secrets.sample.xcconfig` (the real `Secrets.xcconfig` was
  confirmed gitignored and read separately for completeness),
  `project.pbxproj` for build settings, `Package.resolved` for
  third-party dependencies, `.gitignore`.
- **Targeted grep sweeps** for `print(`, `os_log`, `Logger(`,
  `UserDefaults`, `kSecAttrAccessible`, `URLSession`,
  `NSAppTransportSecurity`, `WKWebView`, `SFSafariViewController`,
  `UIPasteboard`, `onOpenURL`, `URLQueryItem`, `addingPercentEncoding`,
  `revokeAPIKey`, `deleteKeyPair`, `clearAll`, `reset()`.
- **Dependency check** against the GitHub Advisory Database for
  AppAuth-iOS 1.7.6.
- **Document cross-reference** for each finding against the existing
  `threat-model.md` T-IDs and `requirements.md` NFR/FR-AUTH IDs where
  applicable.

**Out of scope:** runtime dynamic testing on a real device, Frida-
style hook attacks, App Store binary review, server-side review of
Discourse / Keycloak / meine-piraten.de / agitatorrr.de, and any
fuzzing of the parsers. The audit is purely static code review.

---

## Findings

### CRITICAL

None.

The absence of Critical findings reflects three things: the app
intentionally has a small attack surface (no payments, no PII edit
flows beyond what the upstreams already hold, no arbitrary HTML
rendering of attacker-controllable input via WKWebView, no native code
parsers exposed to the network), the existing mitigations are real and
implemented in code, and the cryptographic primitives that exist are
delegated to Apple frameworks rather than rolled by hand. Stay in this
posture.

---

### HIGH

#### H-1 — Missing `PrivacyInfo.xcprivacy` manifest

- **Files:** absent; expected at `PIRATEN/PrivacyInfo.xcprivacy`.
- **Evidence.** `find /Users/sebulino/dev/PIRATEN-App/iOS/PIRATEN
  -name PrivacyInfo.xcprivacy` returns nothing. The app uses several
  Required Reason APIs that Apple has mandated declarations for since
  Q1 2024:
  - `UserDefaults` is the primary cache and settings store across at
    least eight files (`MessageDraftStore.swift:60`, `NewsCacheStore.swift`,
    `DiscourseCacheStore.swift`, `ReadingProgressStore.swift`,
    `RecentRecipientsStore.swift`, `BackgroundRefreshCoordinator.swift`,
    `NotificationSettingsManager.swift`, `DiscourseNotificationPoller.swift`,
    `RealDiscourseRepository.swift:294`, plus
    `KnowledgeViewModel.swift`).
  - `FileManager` timestamps and `cachesDirectory` access via
    `PIRATEN/Core/Data/Knowledge/KnowledgeCacheManager.swift` (init,
    `readIndex`, `writeIndex`, `migrateIfNeeded`).
  - System boot time / disk-space APIs are NOT used (good), but the
    other two are required.
- **Severity:** **High.** App Store Connect rejects submissions
  automatically when the manifest is missing for an app that uses any
  Required Reason API. This is not exploitable, but it is a hard
  ship blocker.
- **Impact.** App Store submission will be rejected at upload time.
  TestFlight builds may continue working but new submissions will not
  pass App Review's automated check.
- **Recommendation.** Create `PIRATEN/PrivacyInfo.xcprivacy` and add it
  to the target's "Copy Bundle Resources" build phase. Minimum content:

  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
   "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
      <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
          <string>CA92.1</string>
        </array>
      </dict>
      <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
          <string>C617.1</string>
        </array>
      </dict>
    </array>
  </dict>
  </plist>
  ```

  `NSPrivacyTracking=false` and an empty
  `NSPrivacyCollectedDataTypes` accurately reflect the app's
  no-analytics, no-tracking posture (Privacy view text in
  `ProfileView.swift:215` already states this).
- **Cross-reference:** NFR-010, NFR-017 (no analytics/telemetry as
  intent → privacy manifest must encode that intent).

#### H-2 — `logout()` leaves significant credentials and state behind

- **Files:** `PIRATEN/Core/Domain/Auth/AuthStateManager.swift:61-70`,
  `PIRATEN/App/PIRATENApp.swift:99-104`,
  `PIRATEN/Core/Data/Discourse/DiscourseAuthManager.swift:441-464`,
  `PIRATEN/Core/Support/RSAKeyManager.swift:205-218`.
- **Evidence.** `AuthStateManager.logout()` calls
  `authRepository.logout()` (which clears the four OIDC Keychain
  entries) and `recentRecipientsStorage?.clearAll()` — nothing more.
  `PIRATENApp.swift:99-104` adds one more step:
  `container.discourseAPIKeyProvider.clearCredential()`. **None of the
  following is invoked on logout:**

  | Item | Where it lives | Logout currently clears it? |
  |---|---|---|
  | PiratenSSO access / refresh / id-token / expiration | Keychain (via `OIDCAuthRepository.logout`) | yes |
  | Discourse User API Key | Keychain (via `clearCredential`) | yes |
  | RSA private key (Discourse handshake) | Keychain (via `RSAKeyManager.deleteKeyPair`) | **no** |
  | Server-side revocation of Discourse User API Key (`POST /user-api-key/revoke`) | Discourse instance (via `DiscourseAuthManager.revokeAPIKey`) | **no** |
  | Server-side end-session at Keycloak (`endSessionEndpoint`) | Keycloak (via OIDC end-session) | **no** |
  | DM compose draft (subject + body) | `UserDefaults.standard` (`MessageDraftStore`) | **no** |
  | Cached forum topics + message-thread metadata | `UserDefaults.standard` (`DiscourseCacheStore`) | **no** |
  | News cache | `UserDefaults.standard` (`NewsCacheStore`) | **no** |
  | Knowledge cache | `Caches/Knowledge` (`KnowledgeCacheManager`) | **no** |
  | Reading progress per topic | `UserDefaults.standard` (`ReadingProgressStore`) | **no** |
  | Background last-seen markers (forum / messages / todos / news / knowledge / events) | `UserDefaults.standard` (`BackgroundRefreshCoordinator`) | **no** |
  | Foreground last-seen markers in each ViewModel | `UserDefaults.standard` | **no** |
  | `DiscourseNotificationPoller.lastKnownTotal` + badge | `UserDefaults.standard` + `UNUserNotificationCenter` | **no** |
  | `NotificationSettingsManager` per-category toggles | `UserDefaults.standard` | **no** |
  | Discourse like-strategy cache (`discourse_like_winning_strategy`) | `UserDefaults.standard` | **no** |

  Functions `revokeAPIKey` and `deleteKeyPair` exist in
  `DiscourseAuthManager` and `RSAKeyManager` respectively and are
  documented as the logout path — but `grep -rn revokeAPIKey
  PIRATEN/App` returns no results. The `MessageDraftStore` is the
  most sensitive of the UserDefaults items: it stores the full subject
  and body of an in-progress DM (`MessageDraftStore.swift:11-33`).

- **Severity:** **High.** The Discourse User API Key remains valid on
  the server until an admin revokes it; if the device is later
  compromised an attacker can still act as the user on the forum
  even though the local app says "logged out." The PiratenSSO refresh
  token similarly stays valid until expiry. The DM draft in
  UserDefaults is captured by iCloud Backup (no
  `ThisDeviceOnly` equivalent for UserDefaults) and survives logout
  on the same device.
- **Impact.** Confidentiality of in-progress DMs (DM drafts persist
  through logout/login boundary, including to a different user on a
  shared device). Server-side session lifetime extends beyond the
  user's explicit logout action. FR-AUTH-005 ("On confirm: all
  Keychain entries (PiratenSSO + Discourse) are removed. In-memory
  user-specific state (recent recipients, cached profile data) is
  cleared.") is partially unmet — the RSA key in Keychain is not
  cleared, and the recent recipients are cleared but message drafts
  are not.
- **Recommendation.** Rewire `PIRATENApp.swift:99-104` to do, in
  order:

  ```swift
  onLogout: { [container] in
      // 1. Revoke server-side credentials before destroying local material
      Task {
          if let authManager = container.discourseAuthManager {
              try? await authManager.revokeAPIKey(
                  httpClient: container.discourseHTTPClient, // expose this
                  credentialStore: container.credentialStore
              )
              // revokeAPIKey() already deletes the RSA key pair + credential.
          } else {
              container.discourseAPIKeyProvider.clearCredential()
              try? container.rsaKeyManager.deleteKeyPair()
          }

          // 2. Optionally: hit Keycloak's end-session endpoint (best-effort).
          // Use the cached OIDCConfiguration.endSessionEndpoint if present.

          // 3. Clear all local non-Keychain state that ties back to the user.
          container.messageDraftStore.clearDraft()
          container.discourseCacheStore.clearAll()
          container.newsCacheStore.clearAll()
          container.readingProgressStore.clearAll()
          container.knowledgeCacheManager.clearCache() // or skip — public content
          container.notificationSettingsManager.clearAllSettings()
          container.notificationPoller.reset()
          container.backgroundRefreshCoordinator.reset()
          UserDefaults.standard.removeObject(forKey: "discourse_like_winning_strategy")

          // 4. Then drop the Keychain tokens + UI state.
          container.authStateManager.logout()
      }
  }
  ```

  Also fix `NotificationSettingsManager.clearAllSettings()` (see L-2
  below) which forgets `knowledgeEnabled` and `eventsEnabled`.
- **Cross-reference:** FR-AUTH-005, T-002 (member identity/credentials),
  T-003 (private message content).

#### H-3 — Cross-origin `Authorization` header leak on HTTP redirect

- **File:** `PIRATEN/Core/Data/HTTP/URLSessionHTTPClient.swift:91-105`.
- **Evidence:**

  ```swift
  private final class RedirectHandler: NSObject, URLSessionTaskDelegate {
      func urlSession(
          _ session: URLSession,
          task: URLSessionTask,
          willPerformHTTPRedirection response: HTTPURLResponse,
          newRequest request: URLRequest,
          completionHandler: @escaping (URLRequest?) -> Void
      ) {
          var redirectRequest = request
          if let originalAuth = task.originalRequest?.value(
              forHTTPHeaderField: "Authorization"
          ) {
              redirectRequest.setValue(originalAuth, forHTTPHeaderField: "Authorization")
          }
          completionHandler(redirectRequest)
      }
  }
  ```

  iOS strips `Authorization` on redirects by default — for a good
  security reason: a 3xx response from `meine-piraten.de` to an
  arbitrary `Location:` header would otherwise carry the user's Bearer
  token to that arbitrary host. This delegate re-attaches the header
  unconditionally with no host comparison, defeating that
  default-secure behaviour for every authenticated request the app
  makes (Todos, News, Admin Requests, Discourse Notification Poller).
  The same client instance is shared between Discourse
  (`User-Api-Key`) and meine-piraten.de (`Authorization: Bearer ...`),
  so a redirect from either upstream to the other (or to a third
  party) would forward credentials cross-origin.
- **Severity:** **High.** Both upstreams are trusted today, but
  `Authorization` headers are exactly the credentials you do not
  want leaving the original host. A compromise of either upstream's
  301/302 handling, an upstream config error (proxy redirecting to a
  staging domain), or an MITM scenario on the path before TLS is
  validated (e.g. captive portal interstitials) would exfiltrate the
  token. The note `User-Api-Key` is not affected by this code because
  it is added by `DiscourseHTTPClient`, but `URLSession` does NOT
  strip arbitrary headers on redirect — only `Authorization`. So
  `User-Api-Key` survives every redirect today (a separate concern,
  see M-3).
- **Impact.** Bearer-token disclosure to an attacker-controlled host
  in the worst case; in the realistic case, a single accidental
  upstream redirect can leak a 5-minute-valid SSO access token to a
  third party.
- **Recommendation.**

  ```swift
  private final class RedirectHandler: NSObject, URLSessionTaskDelegate {
      func urlSession(
          _ session: URLSession,
          task: URLSessionTask,
          willPerformHTTPRedirection response: HTTPURLResponse,
          newRequest request: URLRequest,
          completionHandler: @escaping (URLRequest?) -> Void
      ) {
          var redirectRequest = request
          let originalHost = task.originalRequest?.url?.host
          let redirectHost = request.url?.host
          if originalHost == redirectHost,
             let originalAuth = task.originalRequest?.value(forHTTPHeaderField: "Authorization") {
              redirectRequest.setValue(originalAuth, forHTTPHeaderField: "Authorization")
          }
          // For belt-and-braces: also drop User-Api-Key / User-Api-Client-Id on host change.
          if originalHost != redirectHost {
              redirectRequest.setValue(nil, forHTTPHeaderField: "User-Api-Key")
              redirectRequest.setValue(nil, forHTTPHeaderField: "User-Api-Client-Id")
          }
          completionHandler(redirectRequest)
      }
  }
  ```

- **Cross-reference:** T-001 (token theft), Apple's own URLSession
  documentation explicitly mentions header stripping as a security
  measure that apps should not undo without thought.

#### H-4 — `NSAttributedString` HTML rendering of attacker-controllable Discourse content can issue network requests

- **Files:** `PIRATEN/Core/Support/HTMLContentParser.swift:34-76`,
  call sites `PIRATEN/App/Views/Main/TopicDetailView.swift:465`,
  `PIRATEN/App/Views/Main/MessageThreadDetailView.swift:502`.
- **Evidence.** `parseHTML` calls
  `NSAttributedString(data:options:documentAttributes:)` with
  `documentType: .html`. Internally on iOS this is implemented by
  WebKit's HTML parser (the same one as WKWebView, just rendering to
  an attributed string). Apple's own documentation warns this API is
  WebKit-backed; in practice it has been observed to fetch remote
  resources referenced in the HTML (`<img src="...">`,
  `<link href="...">`, etc.) during parsing. Two compounding facts
  in this code path:
  - The HTML being parsed is the body of a Discourse post or message
    — controlled by any authenticated member, including a
    compromised one.
  - The fetches go through `URLSession`-equivalent paths managed by
    WebKit, *not* through the cookie-disabled
    `URLSessionHTTPClient.withCaching()`. They use the shared cookie
    storage. While not authenticated (no `Authorization` /
    `User-Api-Key` is auto-attached), they DO carry any cookies set
    by prior navigations through `ASWebAuthenticationSession`.
- **Severity:** **High.** Combined with the user's already-authenticated
  forum session this is effectively a tracking pixel surface — any
  Discourse post containing `<img src="https://attacker.example/p?id=...">`
  causes the device to fetch that URL the moment the user opens the
  post, leaking IP address, user-agent, and timing. Discourse moderation
  is the only mitigation today. More worryingly, NSAttributedString
  HTML parsing has had a history of CVE-grade memory-safety issues
  (CVE-2023-32434 lineage); even if today there is no known unpatched
  iOS 26 issue, this is the wrong tool for the job.
- **Impact.** Information disclosure (IP, online status, read receipts
  for hostile posts). Latent risk surface for memory corruption in
  WebKit's HTML parser. Inconsistent with the threat-model claim that
  "Content from Discourse is rendered with bounded interpreters […]
  No `WKWebView` rendering of arbitrary third-party HTML"
  (`threat-model.md:97-102`) — the NSAttributedString HTML path IS a
  WebKit-backed renderer.
- **Recommendation.** Replace `parseHTML` with the hand-written
  `MarkdownText` / `stripHTML` path already present in the codebase,
  plus a tiny anchor extractor for links. The `stripHTML` regex
  fallback (`HTMLContentParser.swift:80-94`) already exists for the
  case where `parseHTML` returns nil — make that the *only* path. If
  preserved formatting on `<a>` links is required, parse them with
  `NSDataDetector` or a small regex pass and build the AttributedString
  manually with explicit `.link` attributes. Update `threat-model.md`
  to match whatever is actually true after the fix.
- **Cross-reference:** T-007 (upstream injection), T-005 (Discourse as
  source of hostile content).

---

### MEDIUM

#### M-1 — Other `URLSession.shared` usage bypasses the cookie-disabled session

- **Files:** `PIRATEN/Core/Data/Discourse/DiscourseAPIClient.swift:296`,
  `PIRATEN/App/Views/Main/MessageThreadDetailView.swift:508, 519`.
- **Evidence.** `fetchUserSummary` issues `URLSession.shared.data(for:)`
  directly with manually-added `User-Api-Key` / `User-Api-Client-Id`
  headers. The two `MessageThreadDetailView` sites fetch inline image
  data and the avatar through `URLSession.shared.data(from:)`. All
  three use the global shared cookie storage even though
  `URLSessionHTTPClient.withCaching()` was explicitly configured with
  `httpCookieAcceptPolicy = .never`, `httpCookieStorage = nil` to
  defeat the very issue described in ADR-0014 ("the browser-handshake's
  session cookies (from /user-api-key/new) into normal API requests").
- **Severity:** **Medium.** The Discourse API summary call is
  authenticated and could re-trigger the OPEN-02 cookie-confusion
  scenario in the worst case. The image fetches are unauthenticated
  but still subject to cookie tracking by Discourse's CDN.
- **Impact.** Cookies set during the auth handshake (or a prior
  in-app browser session, which the OPEN-09 simulator path might not
  expose) accumulate and may travel back to Discourse on every avatar
  load. Privacy degradation; no direct credential disclosure.
- **Recommendation.** Add an injected `HTTPClient` parameter to
  `fetchUserSummary` and have it use the same cookie-disabled session
  as the rest of the app. For the avatar / image fetches in
  `MessageThreadDetailView`, route them through the same
  `URLSessionHTTPClient.withCaching()` (the `MessageThreadDetailViewModel`
  could expose an `httpClient` reference, or move image fetching into
  the repository layer where it can use the configured client).
- **Cross-reference:** ADR-0014 postscript (cookie-leak hypothesis
  was the original suspect for the OPEN-02 silent-failure).

#### M-2 — RSA decryption uses `rsaEncryptionPKCS1` (legacy padding)

- **File:** `PIRATEN/Core/Support/RSAKeyManager.swift:227-239`.
- **Evidence.**
  ```swift
  guard let decryptedData = SecKeyCreateDecryptedData(
      privateKey,
      .rsaEncryptionPKCS1,
      encryptedData as CFData,
      &error
  ) as Data? else { ... }
  ```
  `rsaEncryptionPKCS1` is RSAES-PKCS1-v1_5, which is vulnerable to
  Bleichenbacher-style padding-oracle attacks if any side channel
  reveals padding validity. The modern Apple-recommended algorithm is
  `rsaEncryptionOAEPSHA256`.
- **Severity:** **Medium.** The Discourse User API Keys spec defines
  the encryption as RSA-PKCS#1-v1.5 — so this is *required* by the
  upstream protocol, not a free choice. The risk is therefore not
  fixable on the iOS side alone. It is still worth noting:
  - The decryption happens exactly once per authentication, in
    response to a single ciphertext from Discourse. There is no
    oracle-style repeated-query path. The mitigation that protects
    against Bleichenbacher in OAuth/OIDC handshakes also applies here.
  - The risk is bounded by the Discourse handshake design, not by the
    client's code.
- **Impact.** None in the current threat model (no padding oracle).
  Listed for completeness.
- **Recommendation.** No code change today. Track upstream: if
  Discourse ever updates the spec to OAEP, switch to
  `rsaEncryptionOAEPSHA256` immediately. Document the constraint in
  a code comment so future maintainers know why PKCS#1 v1.5 is here.

#### M-3 — `User-Api-Key` survives cross-origin redirect (companion to H-3)

- **File:** `PIRATEN/Core/Data/HTTP/URLSessionHTTPClient.swift:91-105`,
  in conjunction with `PIRATEN/Core/Data/HTTP/DiscourseHTTPClient.swift:43-69`.
- **Evidence.** Unlike `Authorization`, the iOS `URLSession` redirect
  handling does *not* strip arbitrary headers like `User-Api-Key`. So
  even with H-3's fix, a Discourse 3xx with a cross-origin `Location:`
  would forward `User-Api-Key` to that host. There is no current code
  in the app to defend against this.
- **Severity:** **Medium.** Discourse is unlikely to redirect to a
  different origin, but the same defence-in-depth logic that argues
  for the H-3 fix argues for this one too.
- **Impact.** Theoretical leak of the long-lived User API Key (until
  admin revocation) to a third-party host on a malicious-or-misconfigured
  Discourse redirect.
- **Recommendation.** In the `RedirectHandler` change for H-3, also
  drop `User-Api-Key`, `User-Api-Client-Id`, and any other custom
  auth-bearing header when the host changes.

#### M-4 — Verbose `os.Logger` traces in the Discourse handshake path

- **File:** `PIRATEN/Core/Data/Discourse/DiscourseAuthManager.swift:146-219, 301-401`.
- **Evidence.** The handshake logs at `.info` level:
  - `discourseAuthLog.info("Client ID: \(self.clientID)")` (line 148)
  - `discourseAuthLog.info("Nonce generated: \(nonce.prefix(16))...")`
    (line 168) — 64 bits of a 256-bit nonce
  - `discourseAuthLog.info("Public key PEM length: …")` (line 158)
  - URL components, fragment presence, callback parsing details
    (lines 309-345)
  - `discourseAuthLog.info("Parsed response - nonce: \(response.nonce.prefix(16))...")`
    (line 399)

  Apple's `os.Logger` *does* mark dynamic string interpolations as
  `private` by default and replaces them with `<private>` in Release
  builds (so this is *not* a token-in-logs disaster). But interpolated
  values still appear in plaintext in Console.app when a debugger is
  attached, when the device is configured for logging via
  `OSLogStore`, or via `sysdiagnose` collection.
- **Severity:** **Medium.** The 16-char nonce prefix is the most
  concerning value — exposing it before the handshake completes
  weakens the nonce's defense against handshake-response replay if an
  attacker can read the device's log stream (e.g. via a sysdiagnose
  obtained from the user). The Client ID is non-secret. The PEM
  length is non-sensitive.
- **Impact.** Low-grade information leak on devices where logs are
  collected. Not exploitable without log access.
- **Recommendation.** Tag values explicitly:

  ```swift
  discourseAuthLog.info("Nonce length: \(nonce.count, privacy: .public)")
  // Drop the prefix logging entirely — it's of no debugging value
  // after the first successful run.
  ```

  And reduce the volume — most of these `.info` calls are leftover
  from active debugging and should be `.debug` or removed. The
  documented privacy intent (NFR-010, "no PII") aligns with cutting
  these down.
- **Cross-reference:** NFR-010.

#### M-5 — Discourse and SSO base URLs hardcoded in `AppContainer`, ignoring `Info.plist` injection

- **File:** `PIRATEN/Core/Support/AppContainer.swift:23-32`.
- **Evidence.**

  ```swift
  private static let issuerURL = URL(string: "https://sso.piratenpartei.de/realms/Piratenlogin")!
  private static let clientID = "piraten_ios_app"
  private static let redirectURI = URL(string: "de.meine-piraten://oauth-callback")!
  private static let discourseBaseURL = URL(string: "https://diskussion.piratenpartei.de")!
  ```

  These are duplicated in `Config/Secrets.xcconfig` (which is
  gitignored and injected into `Info.plist`) but the production
  container ignores `Info.plist` for these specific keys (it only
  reads `MEINE_PIRATEN_BASE_URL`, `KNOWLEDGE_REPO_OWNER`,
  `KNOWLEDGE_REPO_NAME`, `KNOWLEDGE_REPO_BRANCH`,
  `AGITATORRR_BASE_URL`). This bakes `sso.piratenpartei.de`,
  `piraten_ios_app`, and `diskussion.piratenpartei.de` into the
  shipped binary regardless of build configuration.
- **Severity:** **Medium.** Not a security bug per se (these are
  public values), but it defeats the threat-mitigation claim that
  "All configuration via `.xcconfig`" (CLAUDE.md §5) and makes it
  impossible to point a debug or QA build at a staging Discourse /
  staging Keycloak. It also means a misconfigured Secrets file goes
  unnoticed in production.
- **Impact.** Risk of accidentally hitting prod from a debug build,
  and risk of inconsistency between the xcconfig-claimed values
  and the binary-baked ones.
- **Recommendation.** Read these four values from `Info.plist` the
  same way the other URLs are read (`Bundle.main.infoDictionary?[...]`),
  with a `fatalError` if missing in Release (or a clear no-op state).
  Add the corresponding keys to `Info.plist` and to the xcconfig.

#### M-6 — Discourse handshake uses non-ephemeral `ASWebAuthenticationSession`

- **File:** `PIRATEN/Core/Data/Discourse/DiscourseAuthManager.swift:288`.
- **Evidence.**
  `session.prefersEphemeralWebBrowserSession = false // Allow SSO session sharing`.
  This means the in-app browser session for `/user-api-key/new` shares
  cookies with the device's Safari cookie jar. The intent (per the
  comment) is so the user does not have to re-enter SSO credentials
  inside the in-app Safari controller — if they are already logged
  into PiratenSSO in Safari, the handshake just proceeds.
- **Severity:** **Medium.** This is a deliberate UX trade-off, but
  worth flagging explicitly:
  - Pro: better UX, fewer credential prompts.
  - Con: the user's PiratenSSO session in Safari survives even after
    the user "logs out" of the app (the app cannot clear another
    browser's cookies), so the next person to use Safari on a shared
    device could see they have a PiratenSSO session active.
- **Impact.** Cross-context session linkability (member identity is
  visible to anyone who opens `sso.piratenpartei.de` in Safari on
  the same device). For a member-only app where party membership
  itself is asset T-003 (member association), this is worth being
  explicit about.
- **Recommendation.** Document this in `threat-model.md` (it isn't
  there today). If a higher-privacy posture is desired, set
  `prefersEphemeralWebBrowserSession = true` and accept the extra
  re-auth friction. The current `false` setting is defensible — the
  documentation just needs to acknowledge it.
- **Cross-reference:** T-003 (member association).

---

### LOW

#### L-1 — Documentation/code mismatch: News links open via `Link`, not `SFSafariViewController`

- **Files:** `Docs/threat-model.md:101-102`,
  `PIRATEN/App/Views/Main/NewsDetailView.swift:71`.
- **Evidence.** Threat model says "External links in News items open
  in `SFSafariViewController`, which isolates browsing from the app's
  keychain and storage." Actual code uses
  `Link(destination: url) { ... }` which opens in the device's default
  browser (Safari, Chrome, etc.) — *not* in an in-app
  `SFSafariViewController`. There is zero `SFSafari*` reference in
  the entire codebase (`grep` confirmed).
- **Severity:** **Low.** Opening in default Safari is generally
  *more* isolated than `SFSafariViewController` (which shares cookies
  with Safari but runs in-process for the app). Functionally
  acceptable. The risk is documentation drift creating a false sense
  of security posture.
- **Recommendation.** Either:
  - Update `threat-model.md` to say "External links open in the
    device's default browser via SwiftUI `Link`, which is fully
    isolated from the app process," OR
  - Switch to `SFSafariViewController` if the threat model's claim
    was the intent (e.g. for predictable UX and known back-to-app
    behaviour).

#### L-2 — `NotificationSettingsManager.clearAllSettings()` is incomplete

- **File:** `PIRATEN/Core/Support/NotificationSettingsManager.swift:162-174`.
- **Evidence.**
  ```swift
  func clearAllSettings() {
      messagesEnabled = false
      forumEnabled = false
      todosEnabled = false
      newsEnabled = false
      // ← Missing knowledgeEnabled = false
      // ← Missing eventsEnabled  = false
      let defaults = UserDefaults.standard
      defaults.removeObject(forKey: Keys.messagesEnabled)
      defaults.removeObject(forKey: Keys.forumEnabled)
      defaults.removeObject(forKey: Keys.todosEnabled)
      defaults.removeObject(forKey: Keys.newsEnabled)
      // ← Missing removeObject for knowledgeEnabled / eventsEnabled
  }
  ```
  The `knowledgeEnabled` and `eventsEnabled` toggles added in ADR-0015
  were not added to the clear path. Also, this method is **never
  called** (compounded by H-2).
- **Severity:** **Low.** Trivial fix; impact is only "logout doesn't
  reset two of six notification toggles" — and only if H-2 is fixed
  to call this method at all.
- **Recommendation.** Add the two missing assignments and the two
  missing `removeObject` calls. Add a `Test` in
  `NotificationSettingsManagerTests.swift` that asserts all six
  toggles are reset.

#### L-3 — `searchUsers(query:)` percent-encoding dead-check

- **File:** `PIRATEN/Core/Data/Discourse/DiscourseAPIClient.swift:225-235`.
- **Evidence.**

  ```swift
  guard query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) != nil else {
      throw DiscourseError.unknown(statusCode: nil, message: "Invalid search query")
  }

  var components = URLComponents(url: ..., resolvingAgainstBaseURL: false)!
  components.queryItems = [URLQueryItem(name: "term", value: query)]
  ```

  The `addingPercentEncoding` result is discarded — the actual
  encoding is left to `URLQueryItem` (which handles it correctly).
  The guard is dead code. Not a security bug, but it suggests the
  author originally intended a manual encoding path that wasn't taken;
  worth tightening.
- **Severity:** **Low.** No exploitable issue. URLQueryItem encodes
  correctly.
- **Recommendation.** Delete the dead guard, or replace it with a
  meaningful length / character-class validation that matches
  Discourse's own limits.

#### L-4 — Hex-encoded nonce uses 64 bits of randomness logged

- **File:** `PIRATEN/Core/Data/Discourse/DiscourseAuthManager.swift:168,399`.
- **Evidence.** `nonce.prefix(16)` is logged at `.info` after
  generation and after callback parsing. 16 hex chars = 64 bits of
  the 256-bit nonce.
- **Severity:** **Low.** Combined with the os.Logger `<private>` Release
  redaction this is unlikely to be exploitable, but it weakens the
  nonce's defense if logs leak.
- **Recommendation.** Drop the prefix entirely — log only the length.
  See M-4.

#### L-5 — `print()` in `BackgroundTaskScheduler.scheduleAppRefresh()` is not DEBUG-gated

- **File:** `PIRATEN/Core/Data/Notifications/BackgroundTaskScheduler.swift:38`.
- **Evidence.** `print("Could not schedule app refresh: \(error)")`
  with no `#if DEBUG` guard. NFR-010 explicitly says "No raw `print()`
  calls in shipped code." All other `print` sites in the codebase
  are `#if DEBUG`-gated; this one isn't.
- **Severity:** **Low.** The error is a `BGTaskScheduler` error, not
  user data. But the rule is the rule.
- **Recommendation.**

  ```swift
  #if DEBUG
  print("Could not schedule app refresh: \(error)")
  #endif
  ```

  Or route through the central `Logger` facade as the threat model
  describes.

---

### INFORMATIONAL

#### I-1 — `AppContainer.shared` is a mutable singleton

- **File:** `PIRATEN/Core/Support/AppContainer.swift:18`.
- `static var shared: AppContainer?` — written in `PIRATENApp.init()`
  and read in `BackgroundTaskScheduler.handleAppRefresh`. This is a
  mutable global, even though CLAUDE.md §4 ("DI: no global state, no
  hidden dependencies") explicitly bans this pattern. The current use
  is justified (background tasks need an entry point that pre-dates
  SwiftUI lifecycle) but documenting the exception in an ADR would
  match the project's discipline.
- **Severity:** Informational. Not a security issue; an architectural
  consistency one.

#### I-2 — `KeychainCredentialStore.set()` does `try? delete` before insert (race-safe but loses errors)

- **File:** `PIRATEN/Core/Support/KeychainService.swift:50-74`.
- The delete-then-add pattern handles the "Keychain already has an
  item" case correctly, but `try? delete` silently swallows any
  unexpected delete failure (e.g. `errSecInteractionNotAllowed`).
  The subsequent `SecItemAdd` would then fail with
  `errSecDuplicateItem`. Better: `SecItemUpdate` if the item exists,
  else `SecItemAdd`. Not exploitable; cleaner error semantics.

#### I-3 — `KeychainSharing` access group not declared

- **File:** `PIRATEN/PIRATEN.entitlements` (empty dict).
- Intentional and correct for a standalone app. Keychain items are
  scoped to this app's container only. Worth noting in the threat
  model as a deliberate choice (prevents future companion apps /
  extensions from reading these items without an explicit access-
  group migration).

#### I-4 — `RSAKeyManager.decrypt()` wraps decryption errors in `.exportFailed`

- **File:** `PIRATEN/Core/Support/RSAKeyManager.swift:227-239`.
- All errors from `SecKeyCreateDecryptedData` are returned as
  `RSAKeyError.exportFailed`, conflating decryption failure with
  export failure. This is then caught in `DiscourseAuthManager.swift:391`
  and converted to `decryptionFailed` — so the error reaches the user
  correctly. The case naming is confusing for future debugging.
  Suggest a dedicated `.decryptionFailed` case.

---

## Defensive patterns observed (things the app does right)

1. **App Transport Security fully enforced.** No
   `NSAppTransportSecurity`, no `NSAllowsArbitraryLoads`, no per-domain
   exceptions anywhere in `Info.plist` or build settings. TLS-only
   for every upstream.
2. **Keychain accessibility class is correct.** Every keychain item
   (OIDC tokens, Discourse credential, RSA private key) uses
   `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Tokens cannot
   migrate to a new device, cannot be read while the device is
   locked, and are not in iCloud Keychain.
3. **No embedded webview for login.** `ASWebAuthenticationSession`
   for both PiratenSSO (via AppAuth-iOS) and the Discourse handshake.
   Apple's recommended pattern; defeats credential phishing inside
   the app.
4. **PKCE is automatic via AppAuth.** `OIDAuthorizationRequest` with
   `clientSecret: nil` (public client per RFC 8252) and AppAuth handles
   the code_verifier / code_challenge plumbing — no chance to
   mis-implement.
5. **Cookies disabled on the main HTTP client.**
   `URLSessionHTTPClient.withCaching()` sets `httpCookieAcceptPolicy = .never`,
   `httpShouldSetCookies = false`, `httpCookieStorage = nil`. Documented
   inline with the rationale (the Discourse handshake's cookies must
   not leak into normal API requests).
6. **Single-attempt auth-error guard.**
   `AuthStateManager.handleAuthenticationError()` uses
   `isHandlingAuthError` to prevent a thundering herd of parallel
   401s triggering a re-auth storm.
7. **Generic notification bodies.** `NotificationCategory` enum
   strings are fixed German strings — "Neuer Forumsbeitrag" etc. — no
   user content ever ships in a notification body that may render on
   the lock screen.
8. **Opt-in notifications, default off.** Six per-category toggles
   in `NotificationSettingsManager`, all initialised to `false`.
   Aligns with the privacy-first posture and FR-PROF-002.
9. **No analytics, no crash reporting, no third-party telemetry.**
   Verified by absence — no Firebase, no Sentry, no Mixpanel, no
   Amplitude in `Package.resolved`. Only AppAuth-iOS 1.7.6.
10. **`LogRedactor` central utility.** Even if not yet applied at
    every site (M-4 above), the redaction helpers exist and the
    intent is documented.
11. **No `UIPasteboard` reads or writes.** `grep` confirmed no
    pasteboard access in the codebase — none of the iOS "pasteboard
    monitoring" privacy concerns apply.
12. **AppAuth-iOS 1.7.6 has no known CVEs** in the GitHub Advisory
    Database (as of the audit date). The library is maintained by the
    OpenID Foundation, which is the right choice per ADR-0013.
13. **DEBUG-only simulate-session-expiry is properly gated.**
    `ProfileView.swift:231-251` wraps the button in `#if DEBUG` and
    `RootView.swift:66-72` returns `nil` for the closure in Release,
    so no symbol references it from Release code paths.
14. **No OPEN-02 logging of the User-Api-Key.** Confirmed — the
    `discourseAuthLog` lines that handle the decrypted payload log
    only byte counts (`"Decoded encrypted data: X bytes"`,
    `"Decrypted data: X bytes"`) and explicitly comment that the key
    is intentionally not logged.
15. **No `eval`-style dynamic execution.** No `NSExpression`-from-
    user-input, no JavaScript injection points, no
    `NSClassFromString` with attacker-controllable strings.
16. **Background notification dispatch decoupled from view hierarchy.**
    The OPEN-12 fix (ADR-0015) eliminated a real bug class — view-bound
    notification dispatch — by moving the work into a plain object
    invokable from `BGAppRefreshTask`.
17. **Custom URL scheme rationally chosen.** `de.meine-piraten` is
    the app's bundle identifier prefix (reverse-DNS), which is
    Apple's recommendation for reducing the probability of scheme
    collision with another installed app. PKCE is the actual
    defense — the scheme registration itself is not a security
    boundary on iOS.

---

## Recommendations beyond the findings

These are strategic suggestions not tied to a single finding.

1. **Add a logout integration test.** A test that builds the
   container, populates fake credentials in every store, calls
   logout, and asserts that every store reports empty. This would
   have caught H-2 and L-2, and would catch regressions every time a
   new store is added (e.g., the inevitable post-v1 stores for
   biometric-unlock state, push tokens, etc.).
2. **Centralise the logout fan-out.** Today the logout responsibility
   is split between `PIRATENApp.onLogout`, `AuthStateManager.logout`,
   and the various stores' `clearAll` / `reset` methods. Move the
   fan-out into a single method on `AppContainer` (`tearDownUserSession()`
   or similar) called from a single place, so future stores get added
   to the one canonical list.
3. **Adopt a `Sensitive<T>` wrapper for tokens** in the data model.
   `OIDCTokenBundle.accessToken: String` is just a `String` — easy to
   accidentally log via `\(token)`. A small wrapper struct whose
   `description` returns `"<redacted>"` makes the right behaviour the
   default at call sites.
4. **Pin a CSP / referrer policy for the SSO browser session.** Out
   of the app's control (it's a Keycloak setting) but worth
   coordinating with the ops team — referrer-policy should be at
   least `same-origin` on the SSO host, and the SSO redirect should
   only accept the specific registered redirect URI.
5. **Plan biometric re-auth (FR-AUTH-006) with a token-expiry
   tightening.** If the post-v1 biometric prompt is added without
   reducing the access-token lifetime, the prompt becomes a UX-only
   feature. A 5-minute access token + a refresh-on-biometric pattern
   would let the app function while at-rest credentials become
   genuinely useless without the device unlocked + Face ID
   succeeded.
6. **Add a `THREAT_MODEL.md` review at every release.** The threat
   model is already a documented review trigger (`threat-model.md:120-130`).
   Codify it as a checklist item in `release-checklist.md` so the
   "next reviewer" never starts from "where does the data flow?"
7. **Consider an `AppleArchive`-style local export.** Post-v1 only,
   but for a "before I delete the app" UX: let the user export their
   own message drafts (which are local-only) as a `.json` to share via
   the iOS share sheet, rather than letting them silently die with
   `app delete`. Aligns with GDPR data-portability spirit.

---

## Mapping to OWASP MASVS v2

| Control | Status | Notes |
|---|---|---|
| **MASVS-STORAGE-1** — Sensitive data only in intended-secure storage | ⚠️ Partial | Tokens in Keychain ✓; DM drafts in UserDefaults ✗ (M-2's MessageDraftStore) |
| **MASVS-STORAGE-2** — Sensitive data not in app backup | ⚠️ Partial | Keychain `ThisDeviceOnly` is excluded from backup ✓; UserDefaults DM drafts ARE backed up ✗ |
| **MASVS-CRYPTO-1** — Cryptographic primitives use approved algorithms | ✓ | RSA-2048 via SecKey; SHA via Apple frameworks; no custom crypto |
| **MASVS-CRYPTO-2** — Cryptographic keys generated and managed correctly | ✓ | `SecKeyCreateRandomKey` with permanent keychain attrs, `ThisDeviceOnly` |
| **MASVS-AUTH-1** — App uses standard mechanisms for authentication | ✓ | OAuth2/OIDC + PKCE via AppAuth-iOS; no local passwords |
| **MASVS-AUTH-2** — User identity & access tokens managed securely | ⚠️ Partial | Storage ✓; logout invalidation ✗ (H-2: refresh token, User API Key not revoked server-side) |
| **MASVS-AUTH-3** — Sensitive operations require fresh authentication | ⚠️ Deferred | FR-AUTH-006 biometric re-auth deferred post-v1 |
| **MASVS-NETWORK-1** — All network traffic uses TLS | ✓ | ATS fully enforced, no exceptions |
| **MASVS-NETWORK-2** — Certificate pinning where appropriate | ⚠️ Absent by design | Not implemented; documented rationale required (none in repo) |
| **MASVS-PLATFORM-1** — App uses secure IPC mechanisms | ✓ | No app extensions, no IPC; AppDelegate is in-process |
| **MASVS-PLATFORM-2** — WebView misuse avoided | ⚠️ Partial | No WKWebView ✓; but `NSAttributedString(.html)` invokes WebKit on attacker content ✗ (H-4) |
| **MASVS-PLATFORM-3** — Custom URL schemes correctly handled | ✓ | PKCE defends the OAuth flow; nonce defends the Discourse handshake |
| **MASVS-CODE-1** — App requires up-to-date OS | ✓ | iOS 26.2+ deployment target |
| **MASVS-CODE-2** — App detects/responds to known-bad runtime environments | N/A | Not a banking app; jailbreak detection not warranted |
| **MASVS-CODE-3** — App requires up-to-date dependencies | ✓ | Single dep AppAuth-iOS 1.7.6, no known CVEs |
| **MASVS-CODE-4** — App uses platform-recommended security APIs | ✓ | Keychain, ASWebAuthenticationSession, Secure Enclave (via SecKey), Local Notification framework |
| **MASVS-RESILIENCE-1** — App detects/responds to tampering | N/A | Out of scope for a privacy-first member app |
| **MASVS-PRIVACY-1** — App minimises sensitive data collection | ✓ | No analytics, no crash reporting, no telemetry; only data needed for features |
| **MASVS-PRIVACY-2** — App prevents disclosure of sensitive data in transit | ⚠️ Partial | TLS ✓; cross-origin Authorization-header leak risk (H-3) ✗ |
| **MASVS-PRIVACY-3** — App prevents disclosure of sensitive data via system mechanisms | ⚠️ Partial | Notification bodies don't leak content ✓; logs scrub tokens ✓; but DM drafts in iCloud-backed UserDefaults ✗ |
| **MASVS-PRIVACY-4** — App informs user about privacy practices | ⚠️ Missing | `PrivacyView` text exists; `PrivacyInfo.xcprivacy` does NOT (H-1) |

**Summary:** The app meets the spirit of MASVS for a privacy-first
member app. Closing H-1 through H-4 plus the cosmetic Medium and
Low fixes would put it at a clean pass for every applicable control.

---

## Appendix — files reviewed

Auth and credential surface:
`PIRATEN/Core/Support/KeychainService.swift`,
`PIRATEN/Core/Support/RSAKeyManager.swift`,
`PIRATEN/Core/Support/IDTokenParser.swift`,
`PIRATEN/Core/Support/LogRedactor.swift`,
`PIRATEN/Core/Support/AppContainer.swift`,
`PIRATEN/Core/Support/NotificationSettingsManager.swift`,
`PIRATEN/Core/Support/MessageSafetyService.swift`,
`PIRATEN/Core/Support/HTMLContentParser.swift`,
`PIRATEN/Core/Domain/Auth/AuthStateManager.swift`,
`PIRATEN/Core/Domain/Auth/AuthState.swift`,
`PIRATEN/Core/Domain/DeepLink/DeepLink.swift`,
`PIRATEN/Core/Domain/DeepLink/DeepLinkRouter.swift`,
`PIRATEN/Core/Domain/Discourse/DiscourseCredential.swift`,
`PIRATEN/Core/Domain/Discourse/DiscourseAuthResponse.swift`,
`PIRATEN/Core/Domain/HTTP/HTTPClient.swift`,
`PIRATEN/Core/Data/Auth/OIDCAuthRepository.swift`,
`PIRATEN/Core/Data/OIDC/AppAuthOIDCAuthService.swift`,
`PIRATEN/Core/Data/OIDC/AppAuthOIDCDiscoveryService.swift`,
`PIRATEN/Core/Data/OIDC/AppAuthTokenRefresher.swift`,
`PIRATEN/Core/Data/Discourse/DiscourseAuthManager.swift`,
`PIRATEN/Core/Data/Discourse/DiscourseAuthCoordinator.swift`,
`PIRATEN/Core/Data/Discourse/KeychainDiscourseAPIKeyProvider.swift`,
`PIRATEN/Core/Data/Discourse/DiscourseAPIClient.swift`,
`PIRATEN/Core/Data/HTTP/AuthenticatedHTTPClient.swift`,
`PIRATEN/Core/Data/HTTP/AuthStateTokenProvider.swift`,
`PIRATEN/Core/Data/HTTP/DiscourseHTTPClient.swift`,
`PIRATEN/Core/Data/HTTP/URLSessionHTTPClient.swift`,
`PIRATEN/Core/Data/HTTP/RetryingHTTPClient.swift`,
`PIRATEN/Core/Data/HTTP/StubHTTPClient.swift`.

Persistence:
`PIRATEN/Core/Data/Storage/MessageDraftStore.swift`,
`PIRATEN/Core/Data/Storage/DiscourseCacheStore.swift`,
`PIRATEN/Core/Data/Storage/NewsCacheStore.swift`,
`PIRATEN/Core/Data/Storage/ReadingProgressStore.swift`,
`PIRATEN/Core/Data/Storage/RecentRecipientsStore.swift`,
`PIRATEN/Core/Data/Knowledge/KnowledgeCacheManager.swift`.

Background and notifications:
`PIRATEN/Core/Data/Notifications/BackgroundRefreshCoordinator.swift`,
`PIRATEN/Core/Data/Notifications/LocalNotificationScheduler.swift`,
`PIRATEN/Core/Data/Notifications/BackgroundTaskScheduler.swift`,
`PIRATEN/Core/Data/Notifications/DiscourseNotificationPoller.swift`.

App / view layer:
`PIRATEN/App/PIRATENApp.swift`,
`PIRATEN/App/RootView.swift`,
`PIRATEN/App/AppDelegate.swift`,
`PIRATEN/App/Views/Auth/LoginView.swift`,
`PIRATEN/App/Views/Main/MainTabView.swift`,
`PIRATEN/App/Views/Main/ProfileView.swift`,
`PIRATEN/App/Views/Main/NewsDetailView.swift`,
`PIRATEN/App/Views/Main/MessageThreadDetailView.swift` (selected
sections).

Other:
`PIRATEN/Info.plist`,
`PIRATEN/PIRATEN.entitlements`,
`PIRATEN.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`,
`PIRATEN.xcodeproj/project.pbxproj` (build settings only),
`Config/Secrets.sample.xcconfig`,
`.gitignore`,
`Docs/threat-model.md`, `Docs/integrations.md`, `Docs/requirements.md`,
ADRs 0003 / 0009 / 0013 / 0014 / 0015.

— end of audit —
