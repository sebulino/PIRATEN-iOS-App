//
//  SystemAccountsTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 29.05.26.
//

import Testing
@testable import PIRATEN

@Suite("SystemAccounts")
struct SystemAccountsTests {

    @Test("Known automated accounts are recognised as system")
    func knownAccountsAreSystem() {
        #expect(SystemAccounts.isSystem("system"))
        #expect(SystemAccounts.isSystem("discobot"))
        #expect(SystemAccounts.isSystem("robotpirat"))
    }

    @Test("discobot is in the canonical exclusion set")
    func discobotIsExcluded() {
        // Regression guard for the Android-parity fix: discobot PMs every new
        // user, so it must never surface as a human contact.
        #expect(SystemAccounts.usernames.contains("discobot"))
    }

    @Test("Matching is case-insensitive")
    func matchingIsCaseInsensitive() {
        #expect(SystemAccounts.isSystem("Discobot"))
        #expect(SystemAccounts.isSystem("SYSTEM"))
        #expect(SystemAccounts.isSystem("RobotPirat"))
    }

    @Test("Real usernames are not flagged as system")
    func realUsernamesAreNotSystem() {
        #expect(!SystemAccounts.isSystem("ehrlicher_pirat"))
        #expect(!SystemAccounts.isSystem("discobot_fan")) // substring must not match
        #expect(!SystemAccounts.isSystem(""))
    }

    @Test("The canonical set is stored lowercased")
    func setIsLowercased() {
        // isSystem lowercases its input, so every entry must already be
        // lowercase or a correctly-cased username would never match.
        for name in SystemAccounts.usernames {
            #expect(name == name.lowercased(), "System account '\(name)' must be lowercase")
        }
    }
}
