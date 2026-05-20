//
//  DiscourseAPIClient.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// Discourse API client for authenticated requests.
/// Uses AuthenticatedHTTPClient to inject Bearer tokens into all requests.
///
/// ## Authentication Strategy (Q-002)
/// The authentication method depends on how Discourse is configured:
/// - **Bearer passthrough**: If Discourse trusts the same Keycloak realm, the SSO access token
///   is passed directly via `Authorization: Bearer <token>` header
/// - **User API Key**: If Discourse uses its own auth, a `User-Api-Key` header would be needed
///
/// Current implementation assumes Bearer passthrough (Option A from Q-002).
/// See: Docs/OPEN_QUESTIONS.md Q-002 for details.
///
/// ## Rate Limiting
/// Discourse defaults: 20 requests/minute, 2,880 requests/day for authenticated users.
/// No retry logic implemented yet - see Q-006.
///
/// ## Base URL
/// Uses https://diskussion.piratenpartei.de as documented in prd.json.
@MainActor
final class DiscourseAPIClient {

    // MARK: - Properties

    /// The underlying authenticated HTTP client that handles token injection
    private let httpClient: HTTPClient

    /// Base URL for all Discourse API requests
    private let baseURL: URL

    /// API key provider for direct auth header injection (used by summary endpoint)
    private let apiKeyProvider: DiscourseAPIKeyProvider?

    // MARK: - Initialization

    /// Creates a Discourse API client.
    /// - Parameters:
    ///   - httpClient: An authenticated HTTP client (should be AuthenticatedHTTPClient)
    ///   - baseURL: Base URL of the Discourse instance (e.g., https://diskussion.piratenpartei.de)
    ///   - apiKeyProvider: Optional provider for direct auth header injection
    init(httpClient: HTTPClient, baseURL: URL, apiKeyProvider: DiscourseAPIKeyProvider? = nil) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.apiKeyProvider = apiKeyProvider
    }

    // MARK: - Request Helpers

    /// Builds a URL for the given API path.
    /// - Parameter path: API path (e.g., "/latest.json", "/t/123.json")
    /// - Returns: Full URL for the request
    private func url(for path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    /// Creates common headers for Discourse API requests.
    /// - Returns: Headers dictionary with Accept header set
    private func commonHeaders() -> [String: String] {
        // Note: Authorization header is added by AuthenticatedHTTPClient
        [
            "Accept": "application/json"
        ]
    }

    // MARK: - API Methods

    /// Fetches the latest topics from the forum.
    /// Endpoint: GET /latest.json
    /// - Returns: Raw response data for decoding by the caller
    /// - Throws: DiscourseError if the request fails
    func fetchLatest() async throws -> Data {
        let request = HTTPRequest.get(url(for: "/latest.json"), headers: commonHeaders())
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Fetches a single topic with its posts.
    /// Endpoint: GET /t/{topic_id}.json
    /// - Parameters:
    ///   - topicId: The ID of the topic to fetch
    ///   - includeAllPosts: If true, uses print=true to fetch all posts (default: false)
    /// - Returns: Raw response data for decoding by the caller
    /// - Throws: DiscourseError if the request fails
    ///
    /// Note: By default, Discourse returns only the first ~20 posts.
    /// Set includeAllPosts to true to fetch all posts using the print parameter.
    func fetchTopic(id topicId: Int, includeAllPosts: Bool = false) async throws -> Data {
        var urlComponents = URLComponents(url: url(for: "/t/\(topicId).json"), resolvingAgainstBaseURL: false)!

        // Add print=true to fetch all posts
        if includeAllPosts {
            urlComponents.queryItems = [URLQueryItem(name: "print", value: "true")]
        }

        guard let finalURL = urlComponents.url else {
            throw DiscourseError.unknown(statusCode: nil, message: "Failed to construct URL")
        }

        let request = HTTPRequest.get(finalURL, headers: commonHeaders())
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Fetches specific posts by their IDs for a given topic.
    /// Endpoint: GET /t/{topic_id}/posts.json?post_ids[]=...
    /// Used for pagination when the initial response doesn't include all posts.
    /// - Parameters:
    ///   - topicId: The topic containing the posts
    ///   - postIds: Array of post IDs to fetch
    /// - Returns: Raw response data for decoding by the caller
    /// - Throws: DiscourseError if the request fails
    func fetchPostsByIds(topicId: Int, postIds: [Int]) async throws -> Data {
        var urlComponents = URLComponents(url: url(for: "/t/\(topicId)/posts.json"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = postIds.map { URLQueryItem(name: "post_ids[]", value: "\($0)") }

        guard let finalURL = urlComponents.url else {
            throw DiscourseError.unknown(statusCode: nil, message: "Failed to construct URL")
        }

        let request = HTTPRequest.get(finalURL, headers: commonHeaders())
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Fetches private messages inbox for the current user.
    /// Endpoint: GET /topics/private-messages/{username}.json
    /// - Parameter username: The username whose private messages to fetch
    /// - Returns: Raw response data for decoding by the caller
    /// - Throws: DiscourseError if the request fails
    func fetchPrivateMessages(for username: String) async throws -> Data {
        let path = "/topics/private-messages/\(username).json"
        let request = HTTPRequest.get(url(for: path), headers: commonHeaders())
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Fetches sent private messages for the current user.
    /// Endpoint: GET /topics/private-messages-sent/{username}.json
    /// - Parameter username: The username whose sent messages to fetch
    /// - Returns: Raw response data for decoding by the caller
    /// - Throws: DiscourseError if the request fails
    ///
    /// This endpoint returns messages the user has sent that may not yet have replies,
    /// and therefore wouldn't appear in the regular inbox.
    func fetchSentPrivateMessages(for username: String) async throws -> Data {
        let path = "/topics/private-messages-sent/\(username).json"
        let request = HTTPRequest.get(url(for: path), headers: commonHeaders())
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Fetches a specific private message thread.
    /// Endpoint: GET /t/{topic_id}.json (PMs are topics with archetype 'private_message')
    /// - Parameter topicId: The ID of the PM thread (which is a topic)
    /// - Returns: Raw response data for decoding by the caller
    /// - Throws: DiscourseError if the request fails
    func fetchPrivateMessageThread(id topicId: Int) async throws -> Data {
        // PMs in Discourse are just topics with archetype='private_message'
        // The same endpoint works for both
        try await fetchTopic(id: topicId)
    }

    /// Searches for users by username or name.
    /// Endpoint: GET /u/search/users.json?term=<query>
    /// - Parameter query: The search term (minimum 2 characters recommended)
    /// - Returns: Raw response data for decoding by the caller
    /// - Throws: DiscourseError if the request fails
    ///
    /// Response contains array of users with username, name, and avatar_template.
    /// Used for finding recipients when composing new private messages.
    func searchUsers(query: String) async throws -> Data {
        // URL encode the query and build the path with query parameter
        guard query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) != nil else {
            throw DiscourseError.unknown(statusCode: nil, message: "Invalid search query")
        }

        // Build URL with query parameter
        var components = URLComponents(url: baseURL.appendingPathComponent("/u/search/users.json"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "term", value: query)]

        guard let requestUrl = components.url else {
            throw DiscourseError.unknown(statusCode: nil, message: "Failed to build search URL")
        }

        let request = HTTPRequest.get(requestUrl, headers: commonHeaders())
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Fetches a full user profile by username.
    /// Endpoint: GET /u/{username}.json
    /// - Parameter username: The username to fetch the profile for
    /// - Returns: Raw response data for decoding by the caller
    /// - Throws: DiscourseError if the request fails or user not found
    ///
    /// Response contains user object with id, username, name, bio, stats, etc.
    /// Used for displaying user profiles and facilitating messaging.
    func fetchUserProfile(username: String) async throws -> Data {
        let request = HTTPRequest.get(url(for: "/u/\(username).json"), headers: commonHeaders())
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Fetches a user's summary stats (likes given/received).
    /// Endpoint: GET /u/{username}/summary.json
    ///
    /// Uses URLSession directly (not the auth'd DiscourseHTTPClient) to avoid
    /// credential clearing on 403. The summary endpoint is publicly accessible
    /// on Discourse without authentication.
    ///
    /// - Parameter username: The username to fetch the summary for
    /// - Returns: Raw response data, or nil if the request fails
    func fetchUserSummary(username: String) async -> Data? {
        let summaryURL = url(for: "/u/\(username)/summary.json")
        var request = URLRequest(url: summaryURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add Discourse auth headers manually (bypassing DiscourseHTTPClient
        // to avoid credential clearing on 403)
        if let credential = try? await apiKeyProvider?.getAPIKey() {
            request.setValue(credential.apiKey, forHTTPHeaderField: "User-Api-Key")
            request.setValue(credential.clientId, forHTTPHeaderField: "User-Api-Client-Id")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            return nil
        }
        return data
    }

    /// Creates a new private message thread.
    /// Endpoint: POST /posts.json with archetype=private_message
    /// - Parameters:
    ///   - recipient: Username of the recipient
    ///   - title: Subject/title of the message
    ///   - content: The raw markdown content of the message
    /// - Returns: Raw response data containing the created post/topic
    /// - Throws: DiscourseError if the request fails
    func createPrivateMessage(recipient: String, title: String, content: String) async throws -> Data {
        let body = CreatePrivateMessageRequest(
            targetRecipients: recipient,
            title: title,
            raw: content,
            archetype: "private_message"
        )
        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(body)
        } catch {
            throw DiscourseError.unknown(statusCode: nil, message: "Failed to encode request")
        }

        var headers = commonHeaders()
        headers["Content-Type"] = "application/json"

        let request = HTTPRequest.post(url(for: "/posts.json"), body: bodyData, headers: headers)
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Posts a reply to an existing message thread (PM).
    /// Endpoint: POST /posts.json
    /// - Parameters:
    ///   - topicId: The ID of the PM thread to reply to
    ///   - content: The raw markdown content of the reply
    /// - Returns: Raw response data containing the created post
    /// - Throws: DiscourseError if the request fails
    ///
    /// Note: This uses the standard Discourse post creation endpoint.
    /// For PMs, topic_id is sufficient - no category is needed.
    func replyToMessageThread(topicId: Int, content: String) async throws -> Data {
        let body = CreatePostRequest(topicId: topicId, raw: content, replyToPostNumber: nil)
        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(body)
        } catch {
            throw DiscourseError.unknown(statusCode: nil, message: "Failed to encode request")
        }

        var headers = commonHeaders()
        headers["Content-Type"] = "application/json"

        let request = HTTPRequest.post(url(for: "/posts.json"), body: bodyData, headers: headers)
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    // MARK: - Likes (OPEN-02 strategy endpoints)
    //
    // The piratenpartei Discourse instance silently drops POST
    // /post_actions.json (returns 2xx, but the like never persists).
    // See `LikeStrategy.swift` for the strategy chain. The methods below
    // are the per-strategy primitives; `RealDiscourseRepository.likePost`
    // owns the orchestration.

    /// Calls the legacy `/post_actions.json` endpoint. Used by both
    /// `PostActionsJSONStrategy` (formEncoded: false) and
    /// `PostActionsFormStrategy` (formEncoded: true).
    ///
    /// The form-encoded variant reproduces what the Discourse web UI
    /// sends to the live instance byte-for-byte (verified 2026-04-22):
    /// payload `id=...&post_action_type_id=2&flag_topic=false`,
    /// `Content-Type: application/x-www-form-urlencoded; charset=UTF-8`,
    /// `X-Requested-With: XMLHttpRequest`. The third field
    /// (`flag_topic=false`) is included even for likes because some
    /// Discourse builds short-circuit when it's absent.
    ///
    /// CSRF tokens are NOT sent — Discourse bypasses CSRF protection
    /// for User-Api-Key authenticated requests (see
    /// `default_current_user_provider.rb` in the Discourse source).
    ///
    /// Returns `true` when Discourse confirms the action by echoing back
    /// a JSON object containing `acted` or `actions_summary`. Returns
    /// `false` on a 2xx that is empty or omits the confirmation marker —
    /// this is the silent-failure path the OPEN-02 strategy chain exists
    /// to detect.
    func postActionLike(postId: Int, formEncoded: Bool) async throws -> Bool {
        var headers = commonHeaders()
        let bodyData: Data

        if formEncoded {
            // Matches what the Discourse web UI sends from the browser
            // byte-for-byte, including the Accept header. The bare /post_actions
            // path (no .json suffix) with `Accept: */*` keeps Rails out of
            // JSON-format parameter wrapping and lets the form-encoded body
            // arrive at the controller with `id`, `post_action_type_id`, and
            // `flag_topic` at top level.
            headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
            headers["X-Requested-With"] = "XMLHttpRequest"
            headers["Accept"] = "*/*"  // override commonHeaders() default of application/json
            let payload = "id=\(postId)&post_action_type_id=2&flag_topic=false"
            bodyData = Data(payload.utf8)
        } else {
            headers["Content-Type"] = "application/json"
            let body = PostActionRequest(id: postId, postActionTypeId: 2)
            do {
                bodyData = try JSONEncoder().encode(body)
            } catch {
                throw DiscourseError.unknown(statusCode: nil, message: "Failed to encode like request")
            }
        }

        // Path is bare `/post_actions` (no .json suffix) to match what the
        // Discourse web UI sends. Hitting `/post_actions.json` activates
        // Rails' wrap_parameters for JSON-format requests, which moves the
        // form-encoded id and post_action_type_id under a :post_action
        // wrapper key where the controller doesn't look for them, yielding
        // a 400. See ADR-0014 for the empirical narrowing.
        let request = HTTPRequest.post(url(for: "/post_actions"), body: bodyData, headers: headers)

        #if DEBUG
        print("[OPEN-02] postActionLike: postId=\(postId) formEncoded=\(formEncoded)")
        print("[OPEN-02] → URL: \(request.url.absoluteString)")
        print("[OPEN-02] → Headers: \(headers)")
        print("[OPEN-02] → Body: \(String(data: bodyData, encoding: .utf8) ?? "<binary>")")
        #endif

        return try await executeAndConfirm(request)
    }

    /// DELETE /post_actions/{postId}.json — used by both
    /// PostActions strategies. Discourse uses the same DELETE shape
    /// regardless of how the original like was created.
    func postActionUnlike(postId: Int) async throws -> Bool {
        var components = URLComponents(
            url: url(for: "/post_actions/\(postId).json"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "post_action_type_id", value: "2")]

        guard let finalURL = components.url else {
            throw DiscourseError.unknown(statusCode: nil, message: "Failed to construct unlike URL")
        }

        // Match the web UI's XHR markers — defensive against Discourse
        // controllers that gate write actions on this header.
        var headers = commonHeaders()
        headers["X-Requested-With"] = "XMLHttpRequest"
        let request = HTTPRequest(url: finalURL, method: .delete, headers: headers)
        let response: HTTPResponse
        do {
            response = try await httpClient.execute(request)
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
        guard response.isSuccess else {
            throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
        }
        // DELETE returns 200 with empty body on success — no confirmation
        // shape to inspect. Treat 2xx as success.
        return true
    }

    /// POSTs to the discourse-reactions plugin endpoint:
    /// `/discourse-reactions/posts/{postId}/custom-reactions/{reaction}/toggle.json`.
    /// Returns `true` on confirmed toggle, `false` if the endpoint is
    /// missing (404 → plugin not installed) — caller should fall through
    /// to the next strategy.
    func toggleReaction(postId: Int, reaction: String) async throws -> Bool {
        let path = "/discourse-reactions/posts/\(postId)/custom-reactions/\(reaction)/toggle.json"
        var headers = commonHeaders()
        headers["Content-Type"] = "application/json"

        let request = HTTPRequest.post(url(for: path), body: Data(), headers: headers)
        let response: HTTPResponse
        do {
            response = try await httpClient.execute(request)
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }

        // 404 = plugin not installed on this instance — soft failure so
        // the strategy chain moves on without surfacing an error.
        if response.statusCode == 404 {
            return false
        }
        guard response.isSuccess else {
            throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
        }
        // The reactions plugin echoes a JSON object containing the post's
        // current reactions — non-empty body is sufficient confirmation.
        return !response.data.isEmpty
    }

    /// Executes a request and inspects the 2xx response body for a
    /// confirmation marker. Used by `postActionLike` to detect Discourse's
    /// silent-failure mode where the server replies 200 OK but did not
    /// actually persist the action.
    private func executeAndConfirm(_ request: HTTPRequest) async throws -> Bool {
        let response: HTTPResponse
        do {
            response = try await httpClient.execute(request)
        } catch let error as HTTPError {
            #if DEBUG
            print("[OPEN-02] ← HTTPError: \(error)")
            #endif
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            #if DEBUG
            print("[OPEN-02] ← DiscourseAuthError: \(error)")
            #endif
            throw mapDiscourseAuthError(error)
        }

        #if DEBUG
        print("[OPEN-02] ← Status: \(response.statusCode)")
        print("[OPEN-02] ← Response headers: \(response.headers)")
        let bodyForLog = String(data: response.data, encoding: .utf8) ?? "<binary, \(response.data.count) bytes>"
        // Truncate body in log if very large
        let truncatedBody = bodyForLog.count > 2000 ? String(bodyForLog.prefix(2000)) + "…[truncated, total \(bodyForLog.count) chars]" : bodyForLog
        print("[OPEN-02] ← Body: \(truncatedBody)")
        #endif

        guard response.isSuccess else {
            #if DEBUG
            print("[OPEN-02] ← Non-2xx — throwing")
            #endif
            throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
        }

        // Discourse's success response for POST /post_actions.json includes
        // an "actions_summary" array with the user's like recorded. An
        // empty body, or a body lacking this marker, is the silent-failure
        // signature OPEN-02 documents.
        guard let bodyString = String(data: response.data, encoding: .utf8) else {
            #if DEBUG
            print("[OPEN-02] ← Body not UTF-8 — treating as soft fail")
            #endif
            return false
        }
        let hasMarker = bodyString.contains("actions_summary") || bodyString.contains("\"acted\":true")
        #if DEBUG
        print("[OPEN-02] ← actions_summary present: \(bodyString.contains("actions_summary"))")
        print("[OPEN-02] ← acted:true present: \(bodyString.contains("\"acted\":true"))")
        print("[OPEN-02] ← Confirmed: \(hasMarker)")
        #endif
        return hasMarker
    }

    /// Posts a reply to a forum topic post.
    /// Endpoint: POST /posts.json
    /// - Parameters:
    ///   - topicId: The ID of the topic to reply to
    ///   - content: The raw markdown content of the reply
    ///   - replyToPostNumber: Optional post number to reply to (for threading)
    /// - Returns: Raw response data containing the created post
    /// - Throws: DiscourseError if the request fails
    func replyToForumPost(topicId: Int, content: String, replyToPostNumber: Int?) async throws -> Data {
        let body = CreatePostRequest(
            topicId: topicId,
            raw: content,
            replyToPostNumber: replyToPostNumber
        )
        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(body)
        } catch {
            throw DiscourseError.unknown(statusCode: nil, message: "Failed to encode request")
        }

        var headers = commonHeaders()
        headers["Content-Type"] = "application/json"

        let request = HTTPRequest.post(url(for: "/posts.json"), body: bodyData, headers: headers)
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Marks a topic as read by recording read timings.
    /// Endpoint: POST /topics/timings
    /// - Parameters:
    ///   - topicId: The ID of the topic to mark as read
    ///   - highestPostNumber: The highest post number in the topic (marks all posts up to this as read)
    /// - Throws: DiscourseError if the request fails
    func markTopicAsRead(topicId: Int, highestPostNumber: Int) async throws {
        // Discourse expects form-encoded data for the timings endpoint
        var formFields = [
            "topic_id=\(topicId)",
            "topic_time=1000"
        ]
        // Mark each post as read (1000ms read time satisfies Discourse's threshold)
        for postNumber in 1...highestPostNumber {
            formFields.append("timings[\(postNumber)]=1000")
        }
        let bodyString = formFields.joined(separator: "&")
        let bodyData = Data(bodyString.utf8)

        var headers = commonHeaders()
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        let request = HTTPRequest(
            url: url(for: "/topics/timings"),
            method: .post,
            headers: headers,
            body: bodyData
        )
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Archives a private message thread.
    /// Endpoint: PUT /t/{topicId}/archive-message
    /// - Parameter topicId: The ID of the PM topic to archive
    /// - Throws: DiscourseError if the request fails
    func archiveMessageThread(topicId: Int) async throws {
        let request = HTTPRequest(
            url: url(for: "/t/\(topicId)/archive-message"),
            method: .put,
            headers: commonHeaders()
        )
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    // MARK: - Error Mapping

    /// Maps HTTP status codes to Discourse-specific errors.
    private func mapToDiscourseError(statusCode: Int, data: Data) -> DiscourseError {
        // Try to parse Discourse error response
        let message = parseErrorMessage(from: data)

        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 429:
            return .rateLimited
        case 500...599:
            return .serverError(message: message)
        default:
            return .unknown(statusCode: statusCode, message: message)
        }
    }

    /// Maps DiscourseAuthError to DiscourseError.
    private func mapDiscourseAuthError(_ error: DiscourseAuthError) -> DiscourseError {
        switch error {
        case .notAuthenticated:
            return .unauthorized
        default:
            return .unauthorized
        }
    }

    /// Maps HTTPError to DiscourseError.
    private func mapHTTPError(_ error: HTTPError) -> DiscourseError {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .forbidden:
            return .forbidden
        case .notFound:
            return .notFound
        case .networkError(let message):
            return .networkError(message: message)
        case .decodingError(let message):
            return .decodingError(message: message)
        case .cancelled:
            return .cancelled
        case .serverError(let statusCode, let message):
            if statusCode == 429 {
                return .rateLimited
            }
            return .serverError(message: message)
        case .unknown(let message):
            return .unknown(statusCode: nil, message: message)
        }
    }

    /// Attempts to parse an error message from Discourse JSON error response.
    /// Discourse typically returns: { "errors": ["message1", "message2"], "error_type": "..." }
    private func parseErrorMessage(from data: Data) -> String? {
        struct DiscourseErrorResponse: Decodable {
            let errors: [String]?
            let errorType: String?
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        if let errorResponse = try? decoder.decode(DiscourseErrorResponse.self, from: data) {
            return errorResponse.errors?.joined(separator: ", ")
        }
        return nil
    }
}

// MARK: - Request DTOs

/// Request body for creating a post (reply) via POST /posts.json
private struct CreatePostRequest: Encodable {
    let topicId: Int
    let raw: String
    let replyToPostNumber: Int?

    enum CodingKeys: String, CodingKey {
        case topicId = "topic_id"
        case raw
        case replyToPostNumber = "reply_to_post_number"
    }
}

/// Request body for liking a post via POST /post_actions.json
private struct PostActionRequest: Encodable {
    let id: Int
    let postActionTypeId: Int

    enum CodingKeys: String, CodingKey {
        case id
        case postActionTypeId = "post_action_type_id"
    }
}

/// Request body for creating a new private message via POST /posts.json
private struct CreatePrivateMessageRequest: Encodable {
    let targetRecipients: String
    let title: String
    let raw: String
    let archetype: String

    enum CodingKeys: String, CodingKey {
        case targetRecipients = "target_recipients"
        case title
        case raw
        case archetype
    }
}
