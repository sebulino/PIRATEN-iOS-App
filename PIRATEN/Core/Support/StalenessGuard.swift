//
//  StalenessGuard.swift
//  PIRATEN
//

import Foundation

/// Tracks when data was last fetched to prevent redundant API calls.
///
/// A ViewModel uses this to decide whether a load call should actually hit the network
/// or just return the cached result. Pull-to-refresh bypasses the guard via `invalidate()`.
@MainActor
final class StalenessGuard {

    // MARK: - Properties

    /// Minimum time that must pass between fetches.
    let minInterval: TimeInterval

    private var lastFetchTime: Date?

    // MARK: - Initialization

    /// - Parameter minInterval: Minimum seconds between successful fetches.
    init(minInterval: TimeInterval) {
        self.minInterval = minInterval
    }

    // MARK: - API

    /// Returns true if enough time has passed since the last fetch, or if no fetch has happened yet.
    var isStale: Bool {
        guard let last = lastFetchTime else { return true }
        return Date().timeIntervalSince(last) >= minInterval
    }

    /// Records that a fetch just completed successfully.
    func markFetched() {
        lastFetchTime = Date()
    }

    /// Forces the next `isStale` check to return true (for pull-to-refresh).
    func invalidate() {
        lastFetchTime = nil
    }
}
