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

        app.segmentedControls.buttons["Speed → Pace"].tap()
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 3),
            "Keyboard was dismissed by switching conversion direction"
        )

        XCTAssertTrue(hasDecimalPad(in: app), "Speed entry did not get the decimal pad")
        app.segmentedControls.buttons["Pace → Speed"].tap()
        XCTAssertFalse(hasDecimalPad(in: app), "Pace entry did not get the punctuation keyboard")

        dismissKeyboard(in: app)
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForNonExistence(timeout: 3),
            "Tapping outside the card did not dismiss the keyboard"
        )
    }

    @MainActor
    func testScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-runHistoryDemoCompactData"]
        app.launch()

        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        textField.tap()
        textField.typeText("7:30\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        sleep(1)
        addScreenshot(named: "01_pace_to_speed")

        let toolsMenu = app.buttons["Tools menu"]
        XCTAssertTrue(toolsMenu.waitForExistence(timeout: 3))
        toolsMenu.tap()
        app.buttons["Run History"].tap()

        XCTAssertTrue(app.navigationBars["Run History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["10 runs"].waitForExistence(timeout: 3))
        sleep(1)
        addScreenshot(named: "02_run_history")

        app.segmentedControls.buttons["Trends"].tap()
        XCTAssertTrue(element("run-history-speed-trend", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Average · 6 runs"].exists)
        sleep(1)
        addScreenshot(named: "03_speed_trends")

        app.navigationBars["Run History"].buttons.firstMatch.tap()
        XCTAssertTrue(toolsMenu.waitForExistence(timeout: 3))
        toolsMenu.tap()
        app.buttons["Reference Table"].tap()
        XCTAssertTrue(app.navigationBars["Reference"].waitForExistence(timeout: 5))
        sleep(1)
        addScreenshot(named: "04_reference_table")
    }

    @MainActor
    func testReadmeScreenshots() throws {
        let converter = XCUIApplication()
        converter.launchArguments.append("-uiTesting")
        converter.launch()

        let paceField = converter.textFields.firstMatch
        XCTAssertTrue(paceField.waitForExistence(timeout: 3))
        paceField.tap()
        paceField.typeText("7:30\n")
        XCTAssertTrue(converter.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        sleep(1)
        addScreenshot(named: "readme-converter")
        converter.terminate()

        let history = launchRunHistory(with: "-runHistoryDemoCompactData")
        XCTAssertTrue(history.navigationBars["Run History"].waitForExistence(timeout: 5))
        XCTAssertTrue(history.staticTexts["10 runs"].exists)
        sleep(1)
        addScreenshot(named: "readme-run-history")

        history.segmentedControls.buttons["Trends"].tap()
        XCTAssertTrue(element("run-history-speed-trend", in: history).waitForExistence(timeout: 5))
        XCTAssertTrue(history.staticTexts["Average · 6 runs"].exists)
        XCTAssertTrue(history.staticTexts["Faster"].exists)
        history.swipeUp()
        sleep(3)
        addScreenshot(named: "readme-speed-trends")
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

        // Switching distance makes the taller Pace card push the metric picker
        // above the lazy viewport. Return to the top before finding it again.
        for _ in 0..<6 { app.swipeDown() }
        XCTAssertTrue(scrollToElement(element("run-history-trend-metric", in: app), in: app))
        tapAfterScrolling(app.segmentedControls.buttons["Speed"], in: app)
        XCTAssertTrue(app.staticTexts["Your 10K runs are trending based on comparable efforts only."].waitForExistence(timeout: 3))

        tapAfterScrolling(app.segmentedControls.buttons["Volume"], in: app)
        XCTAssertTrue(element("run-history-volume-chart", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testAllRunsTrendIncludesFastRunOutsideNamedDistanceBreakdown() throws {
        let app = launchRunHistory(with: "-runHistoryDemoMixedDistanceData")

        app.segmentedControls.buttons["Trends"].tap()
        XCTAssertTrue(element("run-history-speed-trend", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Overall average-speed trend across every run in this range."].exists)
        XCTAssertTrue(app.staticTexts["Average · 6 runs"].exists)
        XCTAssertTrue(app.staticTexts["Faster"].exists)

        app.segmentedControls.buttons["5K"].tap()
        XCTAssertTrue(app.staticTexts["Your 5K runs are trending based on comparable efforts only."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["5 of 6 runs included · 2.95–3.26 mi"].exists)
        XCTAssertTrue(app.staticTexts["Average · 5 runs"].exists)
        XCTAssertTrue(app.staticTexts["Slower"].exists)
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

        XCTAssertTrue(element("run-history-speed-trend", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Overall average-speed trend across every run in this range."].exists)
        XCTAssertTrue(app.staticTexts["Average · 1 run"].exists)

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

        XCTAssertTrue(
            scrollToElement(monthCard(containing: oldestYear, in: app), in: app),
            "Could not reach the oldest year after switching to All Time"
        )
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

    @MainActor
    func testPersonalBestOpensPreviousRecordHistory() throws {
        let app = launchRunHistory(with: "-runHistoryDemoRecordsData")

        XCTAssertTrue(app.navigationBars["Run History"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Trends"].tap()

        let moreInsights = app.buttons["run-history-more-insights"]
        tapAfterScrolling(moreInsights, in: app)
        XCTAssertTrue(element("run-history-personal-bests", in: app).waitForExistence(timeout: 5))

        let fiveKCell = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] '5K personal best'")
        ).firstMatch
        tapAfterScrolling(fiveKCell, in: app)

        XCTAssertTrue(app.navigationBars["5K Record"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("run-history-record-current", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.staticTexts["Previous best"].exists,
            "The record detail did not show what the current 5K PR beat"
        )
        addScreenshot(named: "record-detail-previous-best")

        XCTAssertTrue(scrollToElement(app.staticTexts["Every record"], in: app))
        addScreenshot(named: "record-detail-progression")

        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Run History"].waitForExistence(timeout: 3))
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

    private func addScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

            let elementIsAboveViewport = element.exists && element.frame.midY < app.frame.midY
            let startY = elementIsAboveViewport ? 0.20 : 0.82
            let endY = elementIsAboveViewport ? 0.82 : 0.20
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: startY))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: endY))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
        return element.exists
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func hasDecimalPad(in app: XCUIApplication) -> Bool {
        let lettersKey = app.keys.matching(
            NSPredicate(format: "label IN {'letters', 'ABC'}")
        ).firstMatch
        return !lettersKey.waitForExistence(timeout: 2)
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
    }
}
