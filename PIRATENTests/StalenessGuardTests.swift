//
//  StalenessGuardTests.swift
//  PIRATENTests
//

import Foundation
import Testing
@testable import PIRATEN

@Suite("StalenessGuard Tests")
@MainActor
struct StalenessGuardTests {

    @Test("isStale is true initially")
    func initiallyStale() {
        let guard_ = StalenessGuard(minInterval: 60)
        #expect(guard_.isStale == true)
    }

    @Test("isStale is false immediately after markFetched")
    func freshAfterFetch() {
        let guard_ = StalenessGuard(minInterval: 60)
        guard_.markFetched()
        #expect(guard_.isStale == false)
    }

    @Test("invalidate forces isStale back to true")
    func invalidateResets() {
        let guard_ = StalenessGuard(minInterval: 60)
        guard_.markFetched()
        #expect(guard_.isStale == false)
        guard_.invalidate()
        #expect(guard_.isStale == true)
    }

    @Test("Zero minInterval always returns stale")
    func zeroInterval() async throws {
        let guard_ = StalenessGuard(minInterval: 0)
        guard_.markFetched()
        // Wait a tiny bit to ensure strictly > 0 elapsed
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        #expect(guard_.isStale == true)
    }

    @Test("Stored minInterval matches init value")
    func storesInterval() {
        let guard_ = StalenessGuard(minInterval: 42)
        #expect(guard_.minInterval == 42)
    }
}
