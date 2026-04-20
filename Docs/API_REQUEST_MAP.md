# API-Anfragen-Übersicht: PIRATEN iOS App

Dieses Dokument beschreibt alle externen Netzwerk-Anfragen der App: welcher Dienst wann, warum und mit welchem Endpoint angesprochen wird.

**Stand:** 2026-04-13

---

## Dienste im Überblick

| Dienst | Basis-URL | Authentifizierung |
|--------|-----------|-------------------|
| **PiratenSSO** | `sso.piratenpartei.de/realms/Piratenlogin` | OAuth2/OIDC (PKCE) |
| **Discourse** | `diskussion.piratenpartei.de` | User-Api-Key (RSA-verschlüsselt) |
| **News** | `meine-piraten.de/api/news` | Keine |
| **Todos** | `meine-piraten.de/tasks.json` | Bearer Token (SSO) |
| **Knowledge Hub** | `api.github.com` (PIRATEN-Kanon) | Keine |
| **Kalender** | `piragitator.de/api/veranstaltung/ical` | Keine |

---

## 1. PiratenSSO

### 1.1 OIDC Discovery
- **Endpoint:** `GET /.well-known/openid-configuration`
- **Wann:** Beim Login-Flow (einmalig pro Anmeldung)
- **Zweck:** Authorization-, Token- und Userinfo-Endpoints ermitteln
- **Datei:** `Core/Data/OIDC/AppAuthOIDCDiscoveryService.swift`

### 1.2 Authorization Code Flow (PKCE)
- **Endpoint:** Browser-basiert via `ASWebAuthenticationSession`
- **Wann:** User tippt "Mit Piratenlogin anmelden"
- **Daten gesendet:** client_id, redirect_uri, scopes (openid, profile, offline_access), PKCE challenge
- **Ergebnis:** Authorization Code via Callback-URL
- **Datei:** `Core/Data/OIDC/AppAuthOIDCAuthService.swift`

### 1.3 Token Exchange
- **Endpoint:** `POST /protocol/openid-connect/token`
- **Wann:** Direkt nach Authorization Code Empfang
- **Daten gesendet:** grant_type=authorization_code, code, code_verifier
- **Ergebnis:** Access Token, Refresh Token, ID Token (JWT mit Profildaten)
- **Datei:** `Core/Data/OIDC/AppAuthOIDCAuthService.swift`

### 1.4 Token Refresh
- **Endpoint:** `POST /protocol/openid-connect/token`
- **Wann:** Vor jeder authentifizierten Anfrage, wenn Access Token < 60s bis Ablauf
- **Daten gesendet:** grant_type=refresh_token, refresh_token, client_id
- **Ergebnis:** Neues Token-Set
- **Bei Fehler:** Session ungueltig, User muss sich neu anmelden
- **Datei:** `Core/Data/OIDC/AppAuthTokenRefresher.swift`

### 1.5 Session-Pruefung (lokal)
- **Endpoint:** Keiner (Keychain-Pruefung)
- **Wann:** App Launch (`RootView.task`)
- **Ablauf:** Tokens im Keychain vorhanden? Ja: ggf. Refresh, dann Authenticated / Nein: LoginView
- **Datei:** `Core/Data/Auth/OIDCAuthRepository.swift`

### 1.6 Profil-Extraktion (lokal)
- **Endpoint:** Keiner (JWT-Parsing)
- **Wann:** Nach erfolgreicher Authentifizierung
- **Daten:** sub, preferred_username, name, email, member_number aus ID Token
- **Datei:** `Core/Data/Auth/OIDCAuthRepository.swift`, `Core/Data/OIDC/IDTokenParser.swift`

---

## 2. Discourse-Authentifizierung (separat von SSO)

### 2.1 User API Key Anforderung
- **Endpoint:** `GET /user-api-key/new` (Browser)
- **Wann:** Bei erstem Discourse-Zugriff oder wenn Key fehlt/ungueltig
- **Daten gesendet:** client_id, nonce, public_key (RSA), scopes (read, write, session_info)
- **Ergebnis:** Verschluesselter User API Key via Callback
- **Speicherung:** Entschluesselt in Keychain
- **Datei:** `Core/Data/Discourse/DiscourseAuthManager.swift`

---

## 3. Discourse Forum

### 3.1 Forum-Themen laden
- **Endpoint:** `GET /latest.json`
- **Zweck:** Liste der aktuellsten Forum-Themen
- **Wann:**
  - **App Launch:** `MainTabView.onAppear` -- verzoegert um 2 Sekunden (Rate-Limit-Schutz)
  - **Tab-Wechsel:** Beim Wechsel zum Forum-Tab
  - **Pull-to-Refresh:** `forumViewModel.refresh()`
  - **Polling:** Alle 60 Sekunden (Hintergrund-Timer, nur im Vordergrund)
- **Caching:** Ja -- `DiscourseCacheStore`, max. 50 Eintraege
- **Datei:** `Core/Data/Discourse/DiscourseAPIClient.swift` (fetchLatest)

### 3.2 Themen-Detail / Beitraege laden
- **Endpoint:** `GET /t/{topic_id}.json` (optional `?print=true` fuer alle Posts)
- **Zweck:** Alle Beitraege eines Forum-Themas
- **Wann:**
  - **Navigation:** User tippt auf ein Thema -> `TopicDetailView.onAppear`
  - **Pull-to-Refresh:** In der Themen-Detailansicht
- **Pagination:** Falls nicht alle Posts geladen: `GET /t/{topic_id}/posts.json?post_ids[]=...`
- **Caching:** Nein
- **Datei:** `Core/Data/Discourse/DiscourseAPIClient.swift` (fetchTopic, fetchPostsByIds)

### 3.3 Nachrichten-Postfach laden
- **Endpoints:**
  - `GET /topics/private-messages/{username}.json` (Eingang)
  - `GET /topics/private-messages-sent/{username}.json` (Gesendet)
- **Zweck:** Liste aller privaten Nachrichtenthreads
- **Wann:**
  - **App Launch:** `MainTabView.onAppear`
  - **Pull-to-Refresh:** `messagesViewModel.refresh()`
  - **Polling:** Alle 60 Sekunden (Hintergrund-Timer)
  - **Deep-Link:** Zum Aufloesen einer Thread-ID
- **Caching:** Ja -- `DiscourseCacheStore`, max. 50 Eintraege
- **Hinweis:** Eingang und Gesendet werden parallel abgerufen
- **Datei:** `Core/Data/Discourse/DiscourseAPIClient.swift` (fetchPrivateMessages, fetchSentPrivateMessages)

### 3.4 Nachrichten-Thread laden
- **Endpoint:** `GET /t/{topic_id}.json`
- **Zweck:** Alle Nachrichten innerhalb eines PM-Threads
- **Wann:**
  - **Navigation:** User tippt auf einen Thread -> `MessageThreadDetailView.onAppear`
  - **Pull-to-Refresh:** In der Thread-Detailansicht
- **Caching:** Nein
- **Datei:** `Core/Data/Discourse/DiscourseAPIClient.swift` (fetchPrivateMessageThread)

### 3.5 Beitrag im Forum senden
- **Endpoint:** `POST /posts.json`
- **Zweck:** Antwort auf ein Forum-Thema
- **Wann:** User tippt "Senden" im Antwort-Composer (TopicDetailView)
- **Daten:** topic_id, raw (Inhalt), reply_to_post_number (optional)
- **Sicherheit:** `MessageSafetyService` prueft Mindestlaenge + Rate-Limit (1 Nachricht / 3 Sek.)
- **Datei:** `Core/Data/Discourse/DiscourseAPIClient.swift` (replyToForumPost)

### 3.6 Antwort auf Nachricht senden
- **Endpoint:** `POST /posts.json`
- **Zweck:** Antwort innerhalb eines PM-Threads
- **Wann:** User tippt "Senden" im Nachrichten-Thread
- **Daten:** topic_id, raw (Inhalt)
- **Sicherheit:** `MessageSafetyService` (wie 3.5)
- **Danach:** Auto-Refresh nach 0.5 Sekunden Verzoegerung
- **Datei:** `Core/Data/Discourse/DiscourseAPIClient.swift` (replyToMessageThread)

### 3.7 Neue Privatnachricht erstellen
- **Endpoint:** `POST /posts.json`
- **Zweck:** Neue Konversation mit einem Empfaenger starten
- **Wann:** User fuellt Compose-Formular aus und tippt "Senden"
- **Daten:** target_recipients, title, raw, archetype="private_message"
- **Sicherheit:** `MessageSafetyService` (wie 3.5)
- **Datei:** `Core/Data/Discourse/DiscourseAPIClient.swift` (createPrivateMessage)

### 3.8 Beitrag liken / unliken
- **Like:** `POST /post_actions.json` -- Body: id, post_action_type_id=2
- **Unlike:** `DELETE /post_actions/{postId}.json?post_action_type_id=2`
- **Zweck:** Zustimmung zu einem Beitrag ausdruecken/zuruecknehmen
- **Wann:** User tippt Herz-Icon auf einem Beitrag
- **UI-Update:** Optimistisch (lokal sofort, API im Hintergrund)
- **Datei:** `Core/Data/Discourse/DiscourseAPIClient.swift` (likePost, unlikePost)

### 3.9 Thema als gelesen markieren
- **Endpoint:** `POST /topics/timings`
- **Zweck:** Leseposition an Discourse melden (fuer Unread-Zaehler)
- **Wann:** Automatisch beim Betrachten eines Themas/Threads (Hintergrund)
- **Daten:** topic_id, topic_time, timings pro Post-Nummer
- **Fehlerbehandlung:** Non-fatal (kein UI-Feedback bei Fehler)
- **Datei:** `Core/Data/Discourse/DiscourseAPIClient.swift` (markTopicAsRead)

### 3.10 Nachricht archivieren
- **Endpoint:** `PUT /t/{topicId}/archive-message`
- **Zweck:** PM-Thread ins Archiv verschieben
- **Wann:** User tippt Archiv-Button im Thread
- **UI-Update:** Optimistisch (Thread wird lokal sofort entfernt)
- **Datei:** `Core/Data/Discourse/DiscourseAPIClient.swift` (archiveMessageThread)

### 3.11 User-Suche
- **Endpoint:** `GET /u/search/users.json?term={query}`
- **Zweck:** Empfaengersuche beim Verfassen einer Nachricht
- **Wann:** Eingabe im Empfaenger-Suchfeld (Compose) -- 300ms Debounce, mind. 2 Zeichen
- **Caching:** Nein
- **Datei:** `Core/Data/Discourse/DiscourseAPIClient.swift` (searchUsers)

### 3.12 User-Profil laden
- **Endpoints:**
  - `GET /u/{username}.json` (Profil)
  - `GET /u/{username}/summary.json` (Likes-Statistik, oeffentlich/unauthentifiziert)
- **Zweck:** Profilinformationen eines Users anzeigen
- **Wann:** User tippt auf einen Benutzernamen
- **Caching:** Nein
- **Datei:** `Core/Data/Discourse/DiscourseAPIClient.swift` (fetchUserProfile, fetchUserSummary)

### 3.13 Benachrichtigungs-Zaehler
- **Endpoint:** `GET /notifications/totals.json`
- **Zweck:** Ungelesene Benachrichtigungen zaehlen (fuer App-Badge)
- **Wann:**
  - **Vordergrund:** Alle 60 Sekunden (Polling-Timer)
  - **App kehrt in Vordergrund zurueck:** Sofortiger Poll + Timer-Neustart
  - **Hintergrund:** Alle 30 Minuten (`BGAppRefreshTask`)
- **Voraussetzung:** Nur wenn Benachrichtigungen vom User aktiviert (Standard: aus)
- **Ergebnis:** Aktualisiert App-Badge
- **Datei:** `Core/Data/Notifications/DiscourseNotificationPoller.swift`

---

## 4. News (meine-piraten.de)

### 4.1 News laden
- **Endpoint:** `GET /api/news?limit=50`
- **Zweck:** Aktuelle Nachrichten der Piratenpartei
- **Wann:**
  - **App Launch:** `MainTabView.onAppear` -> `newsViewModel.loadNews()`
  - **Pull-to-Refresh:** `newsViewModel.refresh()`
  - **Polling:** Alle 60 Sekunden (Hintergrund-Timer)
- **Caching:** Ja -- `NewsCacheStore`, Cache-first-Strategie (gecachte Daten sofort anzeigen, dann Netzwerk)
- **Authentifizierung:** Keine
- **Tracking:** Last-seen News-ID in UserDefaults fuer Badge-Anzeige
- **Datei:** `Core/Data/News/NewsAPIClient.swift`

---

## 5. Todos (meine-piraten.de)

### 5.1 Todos laden
- **Endpoint:** `GET /tasks.json`
- **Zweck:** Aufgabenliste des angemeldeten Mitglieds
- **Wann:**
  - **App Launch:** `MainTabView.onAppear` -> `todosViewModel.loadTodos()`
  - **Pull-to-Refresh:** `todosViewModel.refresh()`
  - **Polling:** Alle 5 Minuten (Hintergrund-Timer)
  - **Deep-Link:** Zum Aufloesen einer Todo-ID
- **Caching:** Nein
- **Authentifizierung:** Bearer Token (SSO Access Token)
- **Datei:** `Core/Data/Todos/TodoAPIClient.swift`

### 5.2 Todo-Detail laden
- **Endpoint:** `GET /tasks/{id}.json`
- **Zweck:** Einzelnes Todo mit Details
- **Wann:** User oeffnet ein Todo

### 5.3 Referenzdaten laden
- **Endpoints:**
  - `GET /entities.json` (Gliederungen)
  - `GET /categories.json` (Kategorien)
- **Zweck:** Metadaten fuer Filter und Zuordnung
- **Wann:** Zusammen mit Todos beim initialen Laden und auf Home-Dashboard

### 5.4 Todo-Aktionen
- **Endpoints:**
  - `POST /tasks.json` -- Todo erstellen
  - `PATCH /tasks/{id}.json` -- Status aendern (claim, complete, uncomplete, unclaim)
  - `DELETE /tasks/{id}.json` -- Todo loeschen
- **Wann:** Jeweilige User-Aktion

### 5.5 Todo-Kommentare
- **Endpoints:**
  - `GET /tasks/{task_id}/comments.json` -- Kommentare laden
  - `POST /tasks/{task_id}/comments.json` -- Kommentar hinzufuegen
  - `DELETE /tasks/{task_id}/comments/{id}.json` -- Kommentar loeschen
- **Wann:** In der Todo-Detailansicht

### 5.6 Admin-Status
- **Endpoints:**
  - `GET /admin_requests/status.json` -- Admin-Status pruefen
  - `POST /admin_requests.json` -- Admin-Zugang anfordern
- **Wann:** Pruefung bei Todo-Verwaltung

---

## 6. Knowledge Hub (GitHub)

### 6.1 Verzeichnis-Index laden
- **Endpoint:** `GET https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={branch}`
- **Zweck:** Inhaltsverzeichnis des Wissens-Repos
- **Wann:**
  - **View erscheint:** `knowledgeViewModel.loadIndex()` in KnowledgeView
  - **Pull-to-Refresh:** `loadIndex(forceRefresh: true)`
  - **Home-Dashboard:** `loadKnowledgeArticles()`
- **Kein periodisches Polling**
- **Caching:** ETag-basiert (conditional requests, 304 Not Modified)
- **Datei:** `Core/Data/Knowledge/GitHubAPIClient.swift`

### 6.2 Artikel-Inhalt laden
- **Endpoint:** Download von GitHub `download_url`
- **Zweck:** Einzelnen Wissensartikel herunterladen
- **Wann:** User oeffnet einen Artikel
- **Caching:** Vollstaendiger Content-Cache mit Fortschritts-Tracking

---

## 7. Kalender (piragitator.de)

### 7.1 Veranstaltungen laden
- **Endpoint:** `GET /api/veranstaltung/ical/1/`
- **Zweck:** Veranstaltungskalender der Piratenpartei
- **Wann:**
  - **View erscheint:** `calendarViewModel.loadEvents()`
  - **Pull-to-Refresh:** `calendarViewModel.refresh()`
  - **Polling:** Alle 5 Minuten (Hintergrund-Timer)
- **Format:** iCal, geparst durch `ICalParser`
- **Caching:** Nein (nur in-memory)
- **Authentifizierung:** Keine
- **Datei:** `Core/Data/Calendar/CalendarAPIClient.swift`

---

## Zeitpunkt-basierte Zusammenfassung

### App Launch (nach Splash Screen)

| Reihenfolge | Anfrage | Dienst | Bedingung |
|-------------|---------|--------|-----------|
| 1 | Session-Pruefung (Keychain) | SSO (lokal) | Immer |
| 2 | Token Refresh | SSO | Nur wenn Token fast abgelaufen |
| 3 | News laden | meine-piraten.de | Immer |
| 4 | Nachrichten laden (Cache-first) | Discourse | Immer |
| 5 | Todos laden | meine-piraten.de | Immer |
| 6 | Forum-Themen laden | Discourse | Verzoegert +2s |
| 7 | Notification-Polling starten | Discourse | Nur wenn aktiviert |

### Tab-Wechsel

| Tab | Anfrage | Dienst |
|-----|---------|--------|
| Forum | `GET /latest.json` | Discourse |
| Knowledge | `loadIndex()` | GitHub |
| Kalender | `loadEvents()` | piragitator.de |
| Todos | Badge-Aktualisierung | (lokal) |

### Pull-to-Refresh

| View | Anfrage(n) | Dienst |
|------|-----------|--------|
| Forum | `GET /latest.json` | Discourse |
| Themen-Detail | `GET /t/{id}.json` | Discourse |
| Nachrichten | Inbox + Sent parallel | Discourse |
| Nachrichten-Thread | `GET /t/{id}.json` | Discourse |
| News | `GET /api/news?limit=50` | meine-piraten.de |
| Todos | `GET /tasks.json` + Referenzdaten | meine-piraten.de |
| Knowledge | `GET /contents/` (force) | GitHub |
| Kalender | `GET /ical/1/` | piragitator.de |

### Periodisches Polling (nur im Vordergrund)

| Dienst | Intervall | Endpoint |
|--------|-----------|----------|
| Forum-Themen | 60s | `GET /latest.json` |
| Nachrichten | 60s | Inbox + Sent |
| News | 60s | `GET /api/news` |
| Todos | 5 min | `GET /tasks.json` |
| Kalender | 5 min | `GET /ical/1/` |
| Benachrichtigungen | 60s | `GET /notifications/totals.json` |

### Hintergrund-Refresh

| Dienst | Intervall | Endpoint |
|--------|-----------|----------|
| Benachrichtigungen | 30 min | `GET /notifications/totals.json` |

### User-Aktionen und resultierende Netzwerk-Anfragen

| Aktion | Anfrage(n) | Dienst |
|--------|-----------|--------|
| Login | Discovery + Auth + Token Exchange | SSO |
| Discourse-Auth | User API Key Flow | Discourse |
| Forum-Beitrag senden | `POST /posts.json` | Discourse |
| Nachricht senden | `POST /posts.json` | Discourse |
| Neue Nachricht verfassen | `POST /posts.json` (archetype=pm) | Discourse |
| Like/Unlike | `POST/DELETE /post_actions` | Discourse |
| Profil anzeigen | `GET /u/{user}.json` + Summary | Discourse |
| Empfaenger suchen | `GET /u/search/users.json` | Discourse |
| Thema als gelesen | `POST /topics/timings` | Discourse |
| Nachricht archivieren | `PUT /t/{id}/archive-message` | Discourse |
| Todo erstellen/aendern | `POST/PATCH /tasks` | meine-piraten.de |
| Todo kommentieren | `POST /tasks/{id}/comments.json` | meine-piraten.de |

---

## Schluessel-Dateien

| Bereich | Datei |
|---------|-------|
| Composition Root | `Core/Support/AppContainer.swift` |
| App Lifecycle | `App/PIRATENApp.swift` |
| View-Triggers | `App/Views/Main/MainTabView.swift` |
| SSO Auth | `Core/Data/OIDC/AppAuthOIDCAuthService.swift` |
| SSO Token Refresh | `Core/Data/OIDC/AppAuthTokenRefresher.swift` |
| SSO Repository | `Core/Data/Auth/OIDCAuthRepository.swift` |
| Discourse Auth | `Core/Data/Discourse/DiscourseAuthManager.swift` |
| Discourse API | `Core/Data/Discourse/DiscourseAPIClient.swift` |
| News API | `Core/Data/News/NewsAPIClient.swift` |
| Todos API | `Core/Data/Todos/TodoAPIClient.swift` |
| Knowledge API | `Core/Data/Knowledge/GitHubAPIClient.swift` |
| Kalender API | `Core/Data/Calendar/CalendarAPIClient.swift` |
| Notification Poller | `Core/Data/Notifications/DiscourseNotificationPoller.swift` |
| Background Tasks | `Core/Data/Notifications/BackgroundTaskScheduler.swift` |
| HTTP-Schicht | `Core/Data/HTTP/` (alle Clients) |
