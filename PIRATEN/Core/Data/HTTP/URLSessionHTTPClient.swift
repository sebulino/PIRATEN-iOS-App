//
//  URLSessionHTTPClient.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// URLSession-based implementation of HTTPClient.
/// Uses modern async/await APIs for network requests.
final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)

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
