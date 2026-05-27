//
//  AppStoreScreenshotTests.swift
//  PIRATENUITests
//
//  UI test that drives the app through each main tab with ScreenshotMode
//  enabled (fake auth + fake data) and saves a screenshot of each as a
//  test attachment. The attachments end up in the .xcresult bundle and
//  are extracted by scripts/extract-screenshots.sh into Docs/screenshots/.
//
//  Run with:
//
//      xcodebuild test \
//        -scheme PIRATEN \
//        -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
//        -only-testing:PIRATENUITests/AppStoreScreenshotTests
//
//  Each screenshot is named "01-kajute", "02-forum", … so they sort
//  in display order matching the App Store listing.
//

import XCTest

@MainActor
final class AppStoreScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// One large test rather than five small ones — keeps the launch
    /// cost low (XCUIApplication.launch is ~3s on a warm simulator,
    /// and reusing the same launched instance preserves navigation state).
    func testGenerateAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ScreenshotMode"]
        app.launch()

        // Splash screen is 1.5s; tabs are present after that.
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 6)

        // Kajüte (Home) — already the default tab after splash.
        sleep(1)
        captureScreen(named: "01-kajute", from: app)

        tapTab(named: "Forum", in: app)
        captureScreen(named: "02-forum", from: app)

        tapTab(named: "Wissen", in: app)
        captureScreen(named: "03-wissen", from: app)

        tapTab(named: "Termine", in: app)
        captureScreen(named: "04-termine", from: app)

        tapTab(named: "ToDos", in: app)
        captureScreen(named: "05-todos", from: app)
    }

    // MARK: - Helpers

    private func tapTab(named name: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 3) {
            tab.tap()
            sleep(1) // let the tab content settle
        } else {
            XCTFail("Tab '\(name)' not found")
        }
    }

    private func captureScreen(named name: String, from app: XCUIApplication) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
