import XCTest

final class pace_to_mphUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testScreenshots() throws {
        let app = XCUIApplication()
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
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
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
}
