//
//  URLSessionHTTPClient.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// URLSession-based implementation of HTTPClient.
/// Uses modern async/await APIs for network requests.
/// Preserves Authorization headers across HTTP redirects (iOS strips them by default).
final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Creates a URLSessionHTTPClient with a caching-enabled session.
    /// Uses a 10 MB memory / 50 MB disk cache (see D-025).
    /// Respects standard HTTP cache headers (Cache-Control, ETag, Last-Modified).
    ///
    /// Cookies are intentionally disabled. The app authenticates exclusively
    /// via header-based credentials — PiratenSSO Bearer token for
    /// meine-piraten.de and Discourse User-Api-Key for the forum — neither of
    /// which need cookies. URLSession's default behavior auto-stores cookies
    /// from Set-Cookie responses and re-sends them on subsequent requests to
    /// the same host. For Discourse this leaks the browser-handshake's session
    /// cookies (from /user-api-key/new) into normal API requests, where they
    /// arrive alongside the User-Api-Key and confuse Discourse's middleware
    /// into treating the request as a browser navigation (expecting a CSRF
    /// token, not finding one, emitting an empty-body 400). Disabling cookies
    /// entirely is both the fix and the privacy-first default.
    static func withCaching() -> URLSessionHTTPClient {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,
            diskCapacity: 50 * 1024 * 1024
        )
        config.requestCachePolicy = .useProtocolCachePolicy
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 30
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        let session = URLSession(configuration: config)
        return URLSessionHTTPClient(session: session)
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let delegate = RedirectHandler()

        do {
            let (data, response) = try await session.data(for: urlRequest, delegate: delegate)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPError.unknown("Invalid response type")
            }

            return HTTPResponse(
                data: data,
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields
            )
        } catch let error as HTTPError {
            throw error
        } catch let error as URLError {
            if error.code == .cancelled {
                throw HTTPError.cancelled
            }
            throw HTTPError.networkError(error.localizedDescription)
        } catch {
            throw HTTPError.unknown(error.localizedDescription)
        }
    }
}

/// Preserves Authorization (and Discourse User-Api-* ) headers when URLSession
/// follows HTTP redirects — **but only when the redirect target is on the same
/// host as the original request**.
///
/// By default, iOS strips Authorization headers on redirect for security. This
/// delegate is needed for legitimate same-host redirects (HTTP→HTTPS, path
/// canonicalization) where the auth header must survive. Re-attaching on a
/// *cross-host* redirect would leak our PiratenSSO Bearer token or Discourse
/// User-Api-Key to a third-party origin — see security audit finding H-3.
///
/// Sensitive headers re-attached on same-host redirects:
///   * `Authorization`              — PiratenSSO Bearer token (meine-piraten.de)
///   * `User-Api-Key`               — Discourse User API Key
///   * `User-Api-Client-Id`         — Discourse client identifier paired with the key
///
/// On a host change, URLSession's default behaviour (drop the headers) is what
/// we want; we simply forward `request` unmodified.
/// Internal so unit tests can exercise the pure host-comparison logic without
/// having to spin up URLSession + a mock URLProtocol stack.
final class RedirectHandler: NSObject, URLSessionTaskDelegate {

    /// Headers that must never travel to a host other than the original.
    /// Kept here as a single source of truth — add any future credential
    /// header to this list rather than re-implementing the check.
    static let sensitiveHeaders = [
        "Authorization",
        "User-Api-Key",
        "User-Api-Client-Id",
    ]

    /// Pure decision function: does the redirect target share a host with
    /// the original request? Case-insensitive (RFC 3986 §3.2.2). Returns
    /// `false` if either host is missing — defensive default treats
    /// "unknown origin" as cross-origin.
    static func isSameHost(original: URL?, redirected: URL?) -> Bool {
        guard let originalHost = original?.host,
              let newHost = redirected?.host
        else { return false }
        return originalHost.caseInsensitiveCompare(newHost) == .orderedSame
    }

    /// Builds the redirect request, re-attaching sensitive headers only on
    /// same-host redirects. Extracted from the delegate method so it's
    /// unit-testable without URLSessionTask.
    static func sanitizedRedirect(
        originalRequest: URLRequest?,
        newRequest: URLRequest
    ) -> URLRequest {
        guard isSameHost(
            original: originalRequest?.url,
            redirected: newRequest.url
        ) else {
            // Cross-host: URLSession has already stripped sensitive headers
            // from `newRequest`; return it unmodified.
            return newRequest
        }

        var redirectRequest = newRequest
        for header in sensitiveHeaders {
            if let value = originalRequest?.value(forHTTPHeaderField: header) {
                redirectRequest.setValue(value, forHTTPHeaderField: header)
            }
        }
        return redirectRequest
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(Self.sanitizedRedirect(
            originalRequest: task.originalRequest,
            newRequest: request
        ))
    }
}
