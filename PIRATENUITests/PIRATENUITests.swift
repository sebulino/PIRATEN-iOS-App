//
//  PIRATENUITests.swift
//  PIRATENUITests
//
//  Created by Sebulino on 29.01.26.
//

import XCTest

final class PIRATENUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAppLaunchesAndShowsLoginScreen() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()

        // Pass UI test mode flag to reset auth state for clean test environment
        app.launchArguments = ["-UITestMode"]
        app.launch()

        // Verify the login screen is displayed
        let loginTitle = app.staticTexts["loginTitle"]
        XCTAssertTrue(loginTitle.waitForExistence(timeout: 5), "Login screen title should be visible")

        let loginButton = app.buttons["loginButton"]
        XCTAssertTrue(loginButton.exists, "Login button should be visible")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // Measures app launch time. NOTE: this test is deliberately
        // EXCLUDED from the nightly CI gate (see .github/workflows/ui-tests.yml)
        // because XCTApplicationLaunchMetric without a committed .xcbaseline
        // fails non-deterministically on shared cloud runners due to high
        // inter-iteration variance. Keep it for local launch-time profiling,
        // but it is not a correctness gate. Run with:
        //   xcodebuild test -only-testing:PIRATENUITests/PIRATENUITests/testLaunchPerformance
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
