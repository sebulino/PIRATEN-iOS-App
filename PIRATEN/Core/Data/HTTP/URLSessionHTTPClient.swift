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

/// Preserves Authorization headers when URLSession follows HTTP redirects.
/// By default, iOS strips Authorization headers on redirect for security.
/// This is needed for API calls where the server may redirect (e.g. HTTP→HTTPS
/// or domain canonicalization) but the auth header must survive.
///
/// Also captures the actual on-the-wire request via URLSessionTaskMetrics for
/// OPEN-02 diagnosis (DEBUG-only). URLSession/CFNetwork auto-adds headers
/// (User-Agent, Accept-Encoding, Connection, possibly Expect) below the
/// URLRequest API surface, so they're invisible to higher-layer logging.
/// Metrics reports the request as it was actually sent.
private final class RedirectHandler: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var redirectRequest = request
        if let originalAuth = task.originalRequest?.value(forHTTPHeaderField: "Authorization") {
            redirectRequest.setValue(originalAuth, forHTTPHeaderField: "Authorization")
        }
        completionHandler(redirectRequest)
    }

    #if DEBUG
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        guard let urlPath = task.originalRequest?.url?.path,
              urlPath.contains("/post_actions") else { return }

        for (i, txn) in metrics.transactionMetrics.enumerated() {
            print("[OPEN-02-NET] --- transaction \(i) ---")
            let req = txn.request
            print("[OPEN-02-NET] method: \(req.httpMethod ?? "?")")
            print("[OPEN-02-NET] URL: \(req.url?.absoluteString ?? "?")")
            print("[OPEN-02-NET] headers as sent:")
            for (k, v) in req.allHTTPHeaderFields ?? [:] {
                // Redact User-Api-Key value to avoid exposing it twice
                let printedValue = (k.lowercased() == "user-api-key") ? "<redacted>" : v
                print("[OPEN-02-NET]   \(k): \(printedValue)")
            }
            print("[OPEN-02-NET] body byte count: \(req.httpBody?.count ?? 0)")
            print("[OPEN-02-NET] protocol: \(txn.networkProtocolName ?? "?")")
            print("[OPEN-02-NET] used proxy: \(txn.isProxyConnection)")
            print("[OPEN-02-NET] reused connection: \(txn.isReusedConnection)")
            print("[OPEN-02-NET] request body bytes sent: \(txn.countOfRequestBodyBytesSent)")
            print("[OPEN-02-NET] response body bytes received: \(txn.countOfResponseBodyBytesReceived)")
            if let resp = txn.response as? HTTPURLResponse {
                print("[OPEN-02-NET] response status: \(resp.statusCode)")
            }
        }
    }
    #endif
}
