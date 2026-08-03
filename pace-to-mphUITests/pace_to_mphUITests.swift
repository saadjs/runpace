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
        tapAfterScrolling(moreInsights, in: app)
        XCTAssertTrue(element("run-history-training-highlights", in: app).waitForExistence(timeout: 5))
        let namedPBs = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS[c] 'Personal best highlights' AND label CONTAINS[c] '1 mile'"
            )
        ).firstMatch
        XCTAssertTrue(namedPBs.exists)
        tapAfterScrolling(moreInsights, in: app)

        // Each tap re-lays out the scroll view, so scroll the next control back
        // into view rather than assuming it held its position.
        tapAfterScrolling(app.segmentedControls.buttons["Pace"], in: app)
        XCTAssertTrue(element("run-history-pace-trend", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Average /mi for your 5K runs only."].exists)

        tapAfterScrolling(app.segmentedControls.buttons["10K"], in: app)
        XCTAssertTrue(app.staticTexts["Average /mi for your 10K runs only."].waitForExistence(timeout: 3))

        tapAfterScrolling(app.segmentedControls.buttons["Speed"], in: app)
        XCTAssertTrue(app.staticTexts["Average MPH per 10K run, with your overall direction."].waitForExistence(timeout: 3))

        tapAfterScrolling(app.segmentedControls.buttons["Volume"], in: app)
        XCTAssertTrue(element("run-history-volume-chart", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testEmptyRunHistoryShowsUnavailableStatesInBothTabs() throws {
        let app = launchRunHistory(with: "-runHistoryDemoEmptyData")

        XCTAssertTrue(app.staticTexts["No runs"].waitForExistence(timeout: 5))

        app.segmentedControls.buttons["Trends"].tap()
        XCTAssertTrue(app.staticTexts["Not enough data"].waitForExistence(timeout: 5))
        XCTAssertFalse(element("run-history-period-comparison", in: app).exists)
    }

    @MainActor
    func testSparseRunHistoryGracefullyShowsUnavailableAnalytics() throws {
        let app = launchRunHistory(with: "-runHistoryDemoSparseData")

        XCTAssertTrue(app.staticTexts["1 run"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Trends"].tap()

        XCTAssertTrue(element("run-history-speed-trend-empty", in: app).waitForExistence(timeout: 5))

        let moreInsights = app.buttons["run-history-more-insights"]
        tapAfterScrolling(moreInsights, in: app)
        XCTAssertTrue(element("run-history-training-highlights", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.staticTexts["No elevation data"], in: app))
    }

    @MainActor
    func testCrossYearEdgeDataSupportsAllTimeAccordion() throws {
        let app = launchRunHistory(with: "-runHistoryDemoEdgeData")

        // The demo scenarios are generated relative to "now", so derive the
        // expected month titles the same way instead of hardcoding years that
        // would silently expire.
        let currentYear = yearLabel(daysAgo: 0)
        let oldestYear = yearLabel(daysAgo: Self.edgeDataOldestRunDaysAgo)
        XCTAssertNotEqual(currentYear, oldestYear, "Edge demo data must span more than one year")

        XCTAssertTrue(app.segmentedControls.buttons["Year"].waitForExistence(timeout: 5))
        XCTAssertTrue(monthCard(containing: currentYear, in: app).waitForExistence(timeout: 5))

        let yearMenu = element("run-history-year-filter", in: app)
        XCTAssertTrue(yearMenu.waitForExistence(timeout: 5))
        yearMenu.tap()
        XCTAssertTrue(app.buttons["All Time"].waitForExistence(timeout: 3))
        app.buttons["All Time"].tap()

        XCTAssertTrue(monthCard(containing: oldestYear, in: app).waitForExistence(timeout: 5))
    }

    /// Expanding one month card must leave every other card's expansion state
    /// untouched. Regression cover for the Year view, where a scroll-wide
    /// `GlassEffectContainer` made the already-open first card re-render when a
    /// sibling animated open.
    @MainActor
    func testExpandingSecondMonthLeavesFirstMonthExpanded() throws {
        let app = launchRunHistory(with: "-runHistoryDemoCompactData")

        XCTAssertTrue(app.segmentedControls.buttons["Year"].waitForExistence(timeout: 5))

        let cards = monthCards(in: app)
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(
            cards.count,
            2,
            "Compact demo data must span at least two months for this test to mean anything"
        )

        let first = cards.element(boundBy: 0)
        let second = cards.element(boundBy: 1)

        // The most recent month opens by default; everything below it starts closed.
        let firstLabel = first.label
        XCTAssertEqual(first.value as? String, "Expanded")
        XCTAssertEqual(second.value as? String, "Collapsed")

        second.tap()

        XCTAssertTrue(
            waitForValue("Expanded", on: second),
            "Tapping the second month card did not expand it"
        )
        XCTAssertEqual(
            first.value as? String,
            "Expanded",
            "Expanding the second month collapsed or reset the first"
        )
        XCTAssertEqual(
            first.label,
            firstLabel,
            "Expanding the second month rebuilt the first card's summary"
        )

        // And collapsing again is still independent.
        second.tap()
        XCTAssertTrue(waitForValue("Collapsed", on: second))
        XCTAssertEqual(first.value as? String, "Expanded")
    }

    private func monthCards(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "run-history-month-card-")
        )
    }

    private func waitForValue(_ expected: String, on element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }

    /// Mirrors the oldest run in `RunHistoryPreviewData.edgeCaseRuns`. Keep in
    /// sync if that scenario changes — the UI test runs out of process and
    /// cannot read the app's demo data directly.
    private static let edgeDataOldestRunDaysAgo = 740

    private func yearLabel(daysAgo: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return String(calendar.component(.year, from: date))
    }

    private func monthCard(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
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
    private func tapAfterScrolling(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(scrollToElement(element, in: app), "Could not reach element to tap", file: file, line: line)
        element.tap()
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
