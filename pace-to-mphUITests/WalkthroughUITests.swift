import XCTest

// Temporary exploratory walkthrough: drives every screen like a user and
// attaches a screenshot + accessibility snapshot at each step.
final class WalkthroughUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    // MARK: - Converter

    @MainActor
    func test01Converter() throws {
        let app = launch()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Keyboard not shown on launch")
        shot("01a-converter-launch", app)

        select("Pace → Speed", in: app)
        let field = app.textFields.firstMatch
        field.typeText("7:30")
        XCTAssertTrue(result(beginning: "8.00", in: app).waitForExistence(timeout: 3), "7:30 /mi should be 8.00 MPH")
        dismissKeyboard(app)
        shot("01b-converter-7-30", app)

        app.buttons["Add to favorites"].tap()
        XCTAssertTrue(app.buttons["Remove from favorites"].waitForExistence(timeout: 3))
        shot("01c-converter-favorited", app)
        app.buttons["Remove from favorites"].tap()
        XCTAssertTrue(app.buttons["Add to favorites"].waitForExistence(timeout: 3), "Unfavoriting did not toggle back")

        for (input, expected) in [("5", "12.00"), ("4:59", "12.04"), ("12:00", "5.00")] {
            replaceText(in: field, with: input)
            XCTAssertTrue(result(beginning: expected, in: app).waitForExistence(timeout: 3), "\(input) /mi should be \(expected)")
        }
        replaceText(in: field, with: "0:00")
        shot("01d-converter-zero", app)

        select("Speed → Pace", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "Keyboard dismissed on direction switch")
        XCTAssertTrue(result(beginning: "No result", in: app).exists, "Switching direction did not clear the input")
        field.typeText("10")
        XCTAssertTrue(result(beginning: "6:00", in: app).waitForExistence(timeout: 3), "10 MPH should be 6:00 /mi")
        dismissKeyboard(app)
        shot("01e-converter-speed-10", app)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.segmentedControls.buttons["Speed → Pace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["Speed → Pace"].isSelected, "Direction not remembered across launches")
        shot("01f-converter-relaunch", app)
        select("Pace → Speed", in: app)
    }

    // MARK: - Favorites

    @MainActor
    func test02Favorites() throws {
        let app = launch()
        open("Favorites", in: app)
        clearFavoritesIfNeeded(app)
        XCTAssertTrue(app.staticTexts["No Favorites"].waitForExistence(timeout: 3))
        shot("02a-favorites-empty", app)

        open("Converter", in: app)
        select("Pace → Speed", in: app)
        let field = app.textFields.firstMatch
        field.tap()
        replaceText(in: field, with: "7:30")
        dismissKeyboard(app)
        app.buttons["Add to favorites"].tap()
        select("Speed → Pace", in: app)
        field.typeText("10")
        dismissKeyboard(app)
        app.buttons["Add to favorites"].tap()
        select("Pace → Speed", in: app)

        open("Favorites", in: app)
        XCTAssertTrue(app.navigationBars["Favorites"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(identifier: "Remove from favorites").count, 2)
        XCTAssertTrue(app.descendants(matching: .any)["7:30 /mi equals 8.00 MPH"].exists, "Pace favorite missing")
        XCTAssertTrue(app.descendants(matching: .any)["10 MPH equals 6:00 /mi"].exists, "Speed favorite missing")
        shot("02b-favorites-two", app)

        app.buttons.matching(identifier: "Remove from favorites").firstMatch.tap()
        XCTAssertTrue(waitForCount(1, of: app.buttons.matching(identifier: "Remove from favorites")))
        shot("02c-favorites-one", app)

        app.navigationBars.buttons["Clear"].tap()
        XCTAssertTrue(app.alerts["Clear Favorites"].waitForExistence(timeout: 3))
        shot("02d-favorites-clear-alert", app)
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "Remove from favorites").count, 1, "Cancel removed favorites")

        app.navigationBars.buttons["Clear"].tap()
        app.alerts.buttons["Clear"].tap()
        XCTAssertTrue(app.staticTexts["No Favorites"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.navigationBars.buttons["Clear"].exists, "Clear button shown with no favorites")
        shot("02e-favorites-cleared", app)
    }

    // MARK: - Calculators

    @MainActor
    func test03RaceCalculator() throws {
        let app = launch()
        dismissKeyboard(app)
        open("Race Calculator", in: app)
        XCTAssertTrue(app.navigationBars["Race Calculator"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "Keyboard not shown for pace input")
        shot("03a-race-empty", app)

        app.textFields["mm:ss"].typeText("8:00")
        dismissKeyboard(app)
        XCTAssertTrue(app.staticTexts["24:51"].waitForExistence(timeout: 3), "8:00 /mi 5K should finish in 24:51")
        XCTAssertTrue(app.staticTexts["7.50"].exists, "8:00 /mi speed should read 7.50")
        shot("03b-race-5k-8-00", app)

        for (distance, time) in [("10K", "49:43"), ("Half", "1:44:53"), ("Full", "3:29:45")] {
            select(distance, in: app)
            XCTAssertTrue(app.staticTexts[time].waitForExistence(timeout: 3), "8:00 /mi \(distance) should be \(time)")
            shot("03c-race-\(distance)", app)
        }

        select("Custom", in: app)
        let custom = app.textFields["0.0"]
        XCTAssertTrue(custom.waitForExistence(timeout: 3), "Custom distance field missing")
        custom.tap()
        custom.typeText("4")
        dismissKeyboard(app)
        XCTAssertTrue(app.staticTexts["32:00"].waitForExistence(timeout: 3), "8:00 /mi for 4 mi should be 32:00")
        shot("03d-race-custom-4", app)

        select("Time → Pace", in: app)
        let time = app.textFields["h:mm:ss"]
        XCTAssertTrue(time.waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["0.0"].exists, "Custom distance lost on mode switch")
        shot("03e-race-time-mode-empty", app)
        time.tap()
        time.typeText("32:00")
        dismissKeyboard(app)
        XCTAssertTrue(app.staticTexts["8:00"].waitForExistence(timeout: 3), "32:00 over 4 mi should be 8:00 /mi")
        shot("03f-race-time-custom", app)

        select("Half", in: app)
        replaceText(in: time, with: "1:45:00")
        dismissKeyboard(app)
        XCTAssertTrue(app.staticTexts["8:01"].waitForExistence(timeout: 3), "1:45:00 half should be 8:01 /mi")
        shot("03g-race-time-half", app)

        select("Pace → Time", in: app)
        XCTAssertTrue(app.textFields["mm:ss"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["1:44:53"].waitForExistence(timeout: 3), "Pace input lost when switching modes")
        shot("03h-race-back-to-pace", app)
    }

    @MainActor
    func test04EvenSplits() throws {
        let app = launch()
        dismissKeyboard(app)
        open("Even Splits", in: app)
        XCTAssertTrue(app.navigationBars["Even Splits"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "Keyboard not shown for time input")
        shot("04a-splits-empty", app)

        app.textFields["h:mm:ss"].typeText("25:00")
        dismissKeyboard(app)
        XCTAssertTrue(app.staticTexts["8:03"].waitForExistence(timeout: 3), "25:00 5K should be 8:03 /mi")
        shot("04b-splits-5k", app)

        select("Full", in: app)
        shot("04c-splits-full", app)

        select("Custom", in: app)
        let custom = app.textFields["0.0"]
        XCTAssertTrue(custom.waitForExistence(timeout: 3))
        custom.tap()
        custom.typeText("5")
        dismissKeyboard(app)
        XCTAssertTrue(app.staticTexts["5:00"].waitForExistence(timeout: 3), "25:00 over 5 mi should be 5:00 /mi")
        shot("04d-splits-custom", app)
    }

    @MainActor
    func test05NegativeSplits() throws {
        let app = launch()
        dismissKeyboard(app)
        open("Negative Splits", in: app)
        XCTAssertTrue(app.navigationBars["Negative Splits"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "Keyboard not shown for time input")
        shot("05a-negative-empty", app)

        app.textFields["h:mm:ss"].typeText("25:00")
        dismissKeyboard(app)
        XCTAssertTrue(app.staticTexts["SPLITS"].waitForExistence(timeout: 3), "Split table missing")
        shot("05b-negative-5k", app)
        app.swipeUp()
        shot("05c-negative-5k-table", app)
        app.swipeDown()

        let drop = app.textFields["5"]
        if drop.waitForExistence(timeout: 3) {
            drop.tap()
            replaceText(in: drop, with: "15")
            dismissKeyboard(app)
        } else {
            XCTFail("Drop-per-split field not found")
        }
        app.swipeUp()
        shot("05d-negative-drop-15", app)
        app.swipeDown()

        select("Half", in: app)
        app.swipeUp()
        shot("05e-negative-half", app)
    }

    // MARK: - Reference

    @MainActor
    func test06Reference() throws {
        let app = launch()
        dismissKeyboard(app)
        open("Reference Table", in: app)
        XCTAssertTrue(app.navigationBars["Reference"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["8:00 /mi equals 7.50 MPH"].exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists, "Keyboard should not show on the reference table")
        shot("06a-reference-top", app)
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["12:00 /mi equals 5.00 MPH"].exists)
        shot("06b-reference-bottom", app)
    }

    // MARK: - Settings & units

    @MainActor
    func test07SettingsUnitsAndDefaultScreen() throws {
        let app = launch()
        dismissKeyboard(app)
        openSettings(app)
        shot("07a-settings", app)

        app.segmentedControls.buttons["KPH"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["KPH"].isSelected)
        shot("07b-settings-kph", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 3))
        let field = app.textFields.firstMatch
        field.tap()
        field.typeText("5:00")
        XCTAssertTrue(result(beginning: "12.00", in: app).waitForExistence(timeout: 3), "5:00 /km should be 12.00 KM/H")
        dismissKeyboard(app)
        shot("07c-converter-kph", app)

        open("Reference Table", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["5:00 /km equals 12.00 KM/H"].waitForExistence(timeout: 3))
        shot("07d-reference-kph", app)

        open("Race Calculator", in: app)
        app.textFields["mm:ss"].typeText("5:00")
        dismissKeyboard(app)
        XCTAssertTrue(app.staticTexts["25:00"].waitForExistence(timeout: 3), "5:00 /km 5K should be 25:00")
        shot("07e-race-kph", app)

        open("Negative Splits", in: app)
        app.textFields["h:mm:ss"].typeText("50:00")
        dismissKeyboard(app)
        select("10K", in: app)
        shot("07f-negative-kph", app)

        open("Run History", in: app)
        XCTAssertTrue(app.navigationBars["Run History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["KM/H"].exists, "Run History not in KM/H")
        shot("07g-history-kph", app)
        select("Trends", in: app)
        shot("07h-trends-kph", app)

        openSettings(app)
        let picker = app.buttons["Default screen"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3), "Default screen picker not found")
        let originalDefault = picker.staticTexts.firstMatch.label
        picker.tap()
        shot("07i-default-screen-menu", app)
        app.buttons["Race Calculator"].firstMatch.tap()
        shot("07j-default-screen-race", app)
        app.segmentedControls.buttons["MPH"].tap()
        app.terminate()

        let real = XCUIApplication()
        real.launchArguments = []
        real.launch()
        XCTAssertTrue(real.navigationBars["Race Calculator"].waitForExistence(timeout: 5), "Default screen not honored at launch")
        XCTAssertTrue(real.keyboards.firstMatch.waitForExistence(timeout: 3), "Keyboard not shown on default race screen")
        XCTAssertTrue(real.buttons["Tools menu"].exists)
        shot("07k-launch-default-race", real)

        dismissKeyboard(real)
        openSettings(real)
        let racePicker = real.buttons["Default screen"]
        XCTAssertTrue(racePicker.waitForExistence(timeout: 3))
        XCTAssertEqual(racePicker.staticTexts.firstMatch.label, "Race Calculator")
        racePicker.tap()
        real.buttons["Converter"].firstMatch.tap()
        real.terminate()
        real.launch()
        XCTAssertTrue(real.segmentedControls.buttons["Pace → Speed"].waitForExistence(timeout: 5), "Converter not honored as default")
        dismissKeyboard(real)
        openSettings(real)
        real.buttons["Default screen"].tap()
        real.buttons[originalDefault].firstMatch.tap()
        real.terminate()
    }

    // MARK: - Run History: Runs tab

    @MainActor
    func test08RunHistoryRuns() throws {
        let app = launch("-runHistoryDemoCompactData")
        dismissKeyboard(app)
        open("Run History", in: app)
        XCTAssertTrue(app.navigationBars["Run History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["10 runs"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.keyboards.firstMatch.exists, "Keyboard leaked into Run History")
        shot("08a-runs-year", app)

        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'run-history-month-card-'"))
        if cards.count >= 2 {
            let second = cards.element(boundBy: 1)
            second.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 22)).tap()
            sleep(1)
            XCTAssertEqual(second.value as? String, "Expanded")
            app.swipeUp()
            shot("08b-runs-year-second-expanded", app)
            app.swipeDown(); app.swipeDown()
        } else {
            XCTFail("Expected at least two month cards")
        }

        let year = app.descendants(matching: .any)["run-history-year-filter"]
        year.tap()
        shot("08c-runs-year-menu", app)
        app.buttons["All Time"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["run-history-all-time-range"].waitForExistence(timeout: 3))
        shot("08d-runs-all-time", app)

        select("Week", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["run-history-week-range"].waitForExistence(timeout: 3))
        shot("08e-runs-week", app)

        select("Month", in: app)
        shot("08f-runs-month", app)
        let month = app.descendants(matching: .any)["run-history-month-filter"]
        XCTAssertTrue(month.waitForExistence(timeout: 3))
        month.tap()
        shot("08g-runs-month-menu", app)
        let options = app.buttons.matching(NSPredicate(format: "label MATCHES '^[A-Z][a-z]+ [0-9]{4}$'"))
        if options.count >= 2 {
            options.element(boundBy: 1).tap()
            shot("08h-runs-previous-month", app)
        } else {
            XCTFail("Month menu had fewer than two months")
            app.tap()
        }

        select("Week", in: app)
        app.swipeUp()
        shot("08i-runs-week-scrolled", app)
        let sync = app.buttons["run-history-sync-now"]
        if scrollTo(sync, in: app) {
            let before = app.staticTexts["run-history-last-synced"].label
            sleep(61 - UInt32(Calendar.current.component(.second, from: Date())))
            sync.tap()
            let after = app.staticTexts["run-history-last-synced"].label
            XCTAssertNotEqual(before, after, "Sync now did not update the last-synced time")
            shot("08j-runs-synced", app)
        } else {
            XCTFail("Sync footer not reachable")
        }
    }

    // MARK: - Run History: Trends tab

    @MainActor
    func test09RunHistoryTrends() throws {
        let app = launch("-runHistoryDemoDenseData")
        dismissKeyboard(app)
        open("Run History", in: app)
        select("Trends", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["run-history-speed-trend"].waitForExistence(timeout: 5))
        shot("09a-trends-top", app)

        for scope in ["Last month", "Last 3 months", "Last 6 months", "Last year", "All time"] {
            let menu = app.buttons["Trend scope"]
            XCTAssertTrue(scrollTo(menu, in: app))
            menu.tap()
            if scope == "Last month" { shot("09b-trends-scope-menu", app) }
            app.buttons[scope].firstMatch.tap()
            XCTAssertTrue(waitFor(menu, valueContains: scope), "Scope did not change to \(scope)")
            _ = scrollTo(app.descendants(matching: .any)["run-history-speed-trend"], in: app)
            shot("09c-trends-scope-\(slug(scope))", app)
        }

        let speedDistances = app.segmentedControls["Distance"].buttons
        let labels = speedDistances.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(labels.contains("ALL"), "Speed distance picker missing: \(labels)")
        for label in labels where label != "ALL" {
            select(label, in: app, within: app.segmentedControls["Distance"])
            XCTAssertTrue(app.descendants(matching: .any)["run-history-speed-inclusion"].waitForExistence(timeout: 3))
            shot("09d-speed-\(slug(label))", app)
        }
        select("ALL", in: app, within: app.segmentedControls["Distance"])

        select("Pace", in: app, within: app.segmentedControls["run-history-trend-metric"])
        XCTAssertTrue(app.descendants(matching: .any)["run-history-pace-trend"].waitForExistence(timeout: 5))
        _ = scrollTo(app.descendants(matching: .any)["run-history-pace-plot"], in: app)
        shot("09e-pace", app)
        let paceDistances = app.segmentedControls["Pace distance"].buttons.allElementsBoundByIndex.map(\.label)
        for label in paceDistances {
            select(label, in: app, within: app.segmentedControls["Pace distance"])
            _ = scrollTo(app.descendants(matching: .any)["run-history-pace-plot"], in: app)
            shot("09f-pace-\(slug(label))", app)
        }

        select("Volume", in: app, within: app.segmentedControls["run-history-trend-metric"])
        XCTAssertTrue(app.descendants(matching: .any)["run-history-volume-chart"].waitForExistence(timeout: 5))
        _ = scrollTo(app.descendants(matching: .any)["run-history-volume-plot"], in: app)
        shot("09g-volume", app)
        scrub(app.descendants(matching: .any)["run-history-volume-plot"], in: app, name: "09h-volume-scrub",
              expecting: app.descendants(matching: .any)["run-history-volume-selection"])

        select("Distance", in: app, within: app.segmentedControls["run-history-trend-metric"])
        XCTAssertTrue(app.descendants(matching: .any)["run-history-distance-trend"].waitForExistence(timeout: 5))
        _ = scrollTo(app.descendants(matching: .any)["run-history-distance-plot"], in: app)
        shot("09i-distance", app)
        scrub(app.descendants(matching: .any)["run-history-distance-plot"], in: app, name: "09j-distance-scrub", expecting: nil)

        select("Speed", in: app, within: app.segmentedControls["run-history-trend-metric"])
        let speedCard = app.descendants(matching: .any)["run-history-speed-trend"]
        _ = scrollTo(speedCard, in: app)
        scrub(speedCard, in: app, name: "09k-speed-scrub", expecting: nil, dy: 0.72)

        select("Pace", in: app, within: app.segmentedControls["run-history-trend-metric"])
        _ = scrollTo(app.descendants(matching: .any)["run-history-pace-plot"], in: app)
        scrub(app.descendants(matching: .any)["run-history-pace-plot"], in: app, name: "09l-pace-scrub", expecting: nil)
    }

    @MainActor
    func test10InsightsAndRecords() throws {
        let app = launch("-runHistoryDemoRecordsData")
        dismissKeyboard(app)
        open("Run History", in: app)
        select("Trends", in: app)
        let more = app.buttons["run-history-more-insights"]
        XCTAssertTrue(scrollTo(more, in: app))
        XCTAssertEqual(more.value as? String, "Collapsed")
        more.tap()
        XCTAssertTrue(app.descendants(matching: .any)["run-history-training-highlights"].waitForExistence(timeout: 3))
        XCTAssertEqual(more.value as? String, "Expanded")
        shot("10a-insights-expanded", app)
        let grid = app.descendants(matching: .any)["run-history-personal-bests"]
        _ = scrollTo(grid, in: app)
        app.swipeUp()
        shot("10b-personal-bests", app)

        let cells = app.buttons.matching(NSPredicate(format: "label CONTAINS 'personal best'"))
        let cellLabels = cells.allElementsBoundByIndex.map(\.label)
        XCTAssertGreaterThan(cellLabels.count, 1, "No PB cells")
        for label in cellLabels {
            let cell = app.buttons[label]
            XCTAssertTrue(scrollTo(cell, in: app), "Can't reach \(label)")
            cell.tap()
            let done = app.buttons["Done"]
            XCTAssertTrue(done.waitForExistence(timeout: 3), "Sheet for \(label) did not open")
            sleep(1)
            let name = slug(String(label.prefix(while: { $0 != "," })))
            shot("10c-detail-\(name)", app)
            app.swipeUp(); app.swipeUp()
            shot("10d-detail-\(name)-bottom", app)
            done.tap()
            XCTAssertTrue(done.waitForNonExistence(timeout: 3))
        }

        let sheetCell = cells.firstMatch
        XCTAssertTrue(scrollTo(sheetCell, in: app))
        sheetCell.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["Done"].waitForNonExistence(timeout: 3), "Swipe-to-dismiss sheet failed")

        XCTAssertTrue(scrollTo(more, in: app))
        more.tap()
        XCTAssertTrue(app.descendants(matching: .any)["run-history-training-highlights"].waitForNonExistence(timeout: 3))
        shot("10e-insights-collapsed", app)
    }

    // MARK: - Run History: data edge cases

    @MainActor
    func test11HistoryScenarios() throws {
        for scenario in ["Empty", "Sparse", "Edge", "MixedDistance", "Records"] {
            let app = launch("-runHistoryDemo\(scenario)Data")
            dismissKeyboard(app)
            open("Run History", in: app)
            XCTAssertTrue(app.navigationBars["Run History"].waitForExistence(timeout: 5))
            sleep(1)
            shot("11-\(slug(scenario))-a-runs", app)
            select("Week", in: app)
            shot("11-\(slug(scenario))-b-week", app)
            select("Trends", in: app)
            sleep(1)
            shot("11-\(slug(scenario))-c-trends", app)
            let more = app.buttons["run-history-more-insights"]
            if more.exists, scrollTo(more, in: app) {
                more.tap()
                sleep(1)
                app.swipeUp()
                shot("11-\(slug(scenario))-d-insights", app)
            }
            for metric in ["Pace", "Volume", "Distance"] {
                let picker = app.segmentedControls["run-history-trend-metric"]
                guard picker.exists else { break }
                select(metric, in: app, within: picker)
                sleep(1)
                shot("11-\(slug(scenario))-e-\(slug(metric))", app)
            }
            app.terminate()
        }
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ extra: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func open(_ screen: String, in app: XCUIApplication) {
        let menu = app.buttons["Tools menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "Tools menu missing")
        menu.tap()
        let item = app.buttons[screen].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3), "\(screen) missing from tools menu")
        item.tap()
        sleep(1)
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        open("Settings", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3), "Settings did not open")
    }

    @MainActor
    private func select(_ title: String, in app: XCUIApplication, within control: XCUIElement? = nil) {
        let segment = (control?.buttons ?? app.segmentedControls.buttons)[title].firstMatch
        for _ in 0..<3 {
            guard scrollTo(segment, in: app) else { break }
            segment.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: segment)
            if XCTWaiter().wait(for: [selected], timeout: 2) == .completed {
                sleep(1)
                return
            }
        }
        XCTFail("Segment \(title) never became selected")
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<20 {
            if element.exists && element.isHittable { return true }
            let above = element.exists && element.frame.midY < app.frame.midY
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: above ? 0.25 : 0.8))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: above ? 0.8 : 0.25))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
        return element.exists && element.isHittable
    }

    // Holds a drag across the plot and captures the screen mid-gesture.
    @MainActor
    private func scrub(_ plot: XCUIElement, in app: XCUIApplication, name: String, expecting selection: XCUIElement?, dy: CGFloat = 0.5) {
        guard plot.exists else { XCTFail("Plot for \(name) missing"); return }
        var sawSelection = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            MainActor.assumeIsolated {
                self.shot(name, app)
                sawSelection = selection?.exists ?? true
            }
        }
        let start = plot.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: dy))
        let end = plot.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: dy))
        start.press(forDuration: 0.3, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 2.5)
        sleep(1)
        if selection != nil {
            XCTAssertTrue(sawSelection, "Scrub selection not shown for \(name)")
            XCTAssertFalse(selection!.exists, "Scrub selection not cleared after release for \(name)")
        }
    }

    private func result(beginning prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    @MainActor
    private func replaceText(in field: XCUIElement, with text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: max(current.count, 12)) + text)
    }

    @MainActor
    private func dismissKeyboard(_ app: XCUIApplication) {
        guard app.keyboards.firstMatch.waitForExistence(timeout: 1) else { return }
        // The converter's dismiss tap lives on its content, below the toolbar strip.
        let hint = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Enter '")).firstMatch
        if hint.exists {
            hint.tap()
            _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 2)
            return
        }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        if app.keyboards.firstMatch.waitForNonExistence(timeout: 2) == false {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
            _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 2)
        }
    }

    @MainActor
    private func clearFavoritesIfNeeded(_ app: XCUIApplication) {
        let clear = app.navigationBars.buttons["Clear"]
        guard clear.waitForExistence(timeout: 1) else { return }
        clear.tap()
        app.alerts.buttons["Clear"].tap()
    }

    private func waitForCount(_ count: Int, of query: XCUIElementQuery) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: query)
        return XCTWaiter().wait(for: [expectation], timeout: 3) == .completed
    }

    private func waitFor(_ element: XCUIElement, valueContains text: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", text), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 3) == .completed
    }

    private func slug(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: " ", with: "-").filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    @MainActor
    private func shot(_ name: String, _ app: XCUIApplication) {
        usleep(400_000)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + ".tree"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
