//
//  CalendarAPIClient.swift
//  PIRATEN
//
//  Created by Claude Code on 19.02.26.
//

import Foundation

/// API client for fetching iCal data from piragitator.de.
/// Uses the base HTTPClient (not authenticated) since the endpoint is public.
/// Follows the same pattern as TodoAPIClient.
@MainActor
final class CalendarAPIClient {

    // MARK: - Constants

    /// Path to the iCal feed endpoint
    private static let iCalPath = "/api/veranstaltung/ical/1/"

    // MARK: - Properties

    private let httpClient: HTTPClient
    private let baseURL: URL

    // MARK: - Initialization

    init(httpClient: HTTPClient, baseURL: URL) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    // MARK: - Public API

    /// Fetches the raw iCal data from the piragitator.de feed.
    /// - Returns: The iCal text content as a String
    /// - Throws: CalendarError if the request fails
    func fetchICalData() async throws -> String {
        let url = baseURL.appendingPathComponent(Self.iCalPath)
        let request = HTTPRequest.get(url, headers: ["Accept": "text/calendar"])

        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw CalendarError.networkError("Server returned status \(response.statusCode)")
            }
            guard let text = String(data: response.data, encoding: .utf8) else {
                throw CalendarError.parsingError("Response is not valid text")
            }
            return text
        } catch let error as CalendarError {
            throw error
        } catch {
            throw CalendarError.networkError(error.localizedDescription)
        }
    }
}
