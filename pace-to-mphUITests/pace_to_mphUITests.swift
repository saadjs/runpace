import XCTest

final class pace_to_mphUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testKeyboardAutomaticallyOpensReliably() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTesting")

        // Repeated cold launches catch regressions caused by focus requests
        // racing the app's initial presentation.
        for launch in 1...5 {
            app.launch()
            XCTAssertTrue(
                app.keyboards.firstMatch.waitForExistence(timeout: 3),
                "Keyboard did not appear after launch \(launch)"
            )
            app.terminate()
        }

        app.launch()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        dismissKeyboard(in: app)

        let toolsMenu = app.buttons["Tools menu"]
        XCTAssertTrue(toolsMenu.waitForExistence(timeout: 3))
        toolsMenu.tap()
        app.buttons["Race Calculator"].tap()

        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 3),
            "Keyboard did not appear after navigating to an input screen"
        )

        dismissKeyboard(in: app)
        app.navigationBars["Race Calculator"].buttons.firstMatch.tap()

        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 3),
            "Keyboard did not reappear after returning to the converter"
        )
    }

    @MainActor
    func testScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTesting")
        app.launch()
        sleep(1)

        // Screenshot 1: Empty state
        let emptyAttachment = XCTAttachment(screenshot: app.screenshot())
        emptyAttachment.name = "01_empty"
        emptyAttachment.lifetime = .keepAlways
        add(emptyAttachment)

        // Tap the text field and type a pace
        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 3))
        textField.tap()
        textField.typeText("7:30")
        sleep(1)

        // Dismiss keyboard by tapping the middle of the screen (below card, above controls)
        dismissKeyboard(in: app)
        sleep(2)

        // Screenshot 2: Pace to Speed with result (no keyboard)
        let paceAttachment = XCTAttachment(screenshot: app.screenshot())
        paceAttachment.name = "02_pace_to_speed"
        paceAttachment.lifetime = .keepAlways
        add(paceAttachment)

        // Navigate to reference table via toolbar menu
        let toolsMenu = app.buttons["Tools menu"]
        XCTAssertTrue(toolsMenu.waitForExistence(timeout: 3))
        toolsMenu.tap()

        let referenceTable = app.buttons["Reference Table"]
        XCTAssertTrue(referenceTable.waitForExistence(timeout: 3))
        referenceTable.tap()
        sleep(1)

        // Screenshot 3: Reference table
        let refAttachment = XCTAttachment(screenshot: app.screenshot())
        refAttachment.name = "03_reference_table"
        refAttachment.lifetime = .keepAlways
        add(refAttachment)
    }

    @MainActor
    func testDenseRunHistoryAnalyticsEndToEnd() throws {
        let app = launchRunHistory(with: "-runHistoryDemoDenseData")

        XCTAssertTrue(app.navigationBars["Run History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["Year"].isSelected)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'run'")).firstMatch.exists)

        app.segmentedControls.buttons["Trends"].tap()
        XCTAssertTrue(element("run-history-speed-trend", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("run-history-period-comparison", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Avg /mi"].exists)

        let moreInsights = app.buttons["run-history-more-insights"]
        XCTAssertTrue(scrollToElement(moreInsights, in: app))
        moreInsights.tap()
        XCTAssertTrue(element("run-history-training-highlights", in: app).waitForExistence(timeout: 5))
        let namedPBs = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS[c] 'Personal best highlights' AND label CONTAINS[c] '1 mile'"
            )
        ).firstMatch
        XCTAssertTrue(namedPBs.exists)
        moreInsights.tap()

        let paceButton = app.segmentedControls.buttons["Pace"]
        XCTAssertTrue(scrollToElement(paceButton, in: app))
        paceButton.tap()
        let paceCard = element("run-history-pace-trend", in: app)
        XCTAssertTrue(paceCard.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Average /mi for your 5K runs only."].exists)

        app.segmentedControls.buttons["10K"].tap()
        XCTAssertTrue(app.staticTexts["Average /mi for your 10K runs only."].waitForExistence(timeout: 3))

        app.segmentedControls.buttons["Speed"].tap()
        XCTAssertTrue(app.staticTexts["Average MPH per 10K run, with your overall direction."].waitForExistence(timeout: 3))

        app.segmentedControls.buttons["Volume"].tap()
        let volumeCard = element("run-history-volume-chart", in: app)
        XCTAssertTrue(volumeCard.waitForExistence(timeout: 5))
    }

    @MainActor
    func testSparseRunHistoryGracefullyShowsUnavailableAnalytics() throws {
        let app = launchRunHistory(with: "-runHistoryDemoSparseData")

        XCTAssertTrue(app.staticTexts["1 run"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Trends"].tap()

        XCTAssertTrue(element("run-history-speed-trend-empty", in: app).waitForExistence(timeout: 5))

        let moreInsights = app.buttons["run-history-more-insights"]
        XCTAssertTrue(scrollToElement(moreInsights, in: app))
        moreInsights.tap()
        XCTAssertTrue(element("run-history-training-highlights", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.staticTexts["No elevation data"], in: app))
    }

    @MainActor
    func testCrossYearEdgeDataSupportsAllTimeAccordion() throws {
        let app = launchRunHistory(with: "-runHistoryDemoEdgeData")

        XCTAssertTrue(app.segmentedControls.buttons["Year"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS '2026'")).firstMatch.exists)

        let yearMenu = element("run-history-year-filter", in: app)
        XCTAssertTrue(yearMenu.waitForExistence(timeout: 5))
        yearMenu.tap()
        XCTAssertTrue(app.buttons["All Time"].waitForExistence(timeout: 3))
        app.buttons["All Time"].tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS '2024'")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    private func launchRunHistory(with seedArgument: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [seedArgument]
        app.launch()

        let toolsMenu = app.buttons["Tools menu"]
        XCTAssertTrue(toolsMenu.waitForExistence(timeout: 5))
        toolsMenu.tap()
        let runHistory = app.buttons["Run History"]
        XCTAssertTrue(runHistory.waitForExistence(timeout: 3))
        runHistory.tap()
        return app
    }

    @MainActor
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<20 {
            if element.exists && element.isHittable { return true }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.82))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.20))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
        return element.exists
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
    }
}
