import Testing
import Foundation
@testable import pace_to_mph

struct ConversionEngineTests {

    // MARK: - Pace Parsing

    @Test func parsePaceWithColonFormat() {
        let result = ConversionEngine.parsePace("8:30")
        #expect(result != nil)
        #expect(abs(result! - 8.5) < 0.001)
    }

    @Test func parsePaceWithDecimalFormat() {
        let result = ConversionEngine.parsePace("8.5")
        #expect(result == 8.5)
    }

    @Test func parsePaceWithZeroSeconds() {
        let result = ConversionEngine.parsePace("7:00")
        #expect(result == 7.0)
    }

    @Test func parsePaceEmpty() {
        #expect(ConversionEngine.parsePace("") == nil)
        #expect(ConversionEngine.parsePace("   ") == nil)
    }

    @Test func parsePaceInvalid() {
        #expect(ConversionEngine.parsePace("abc") == nil)
        #expect(ConversionEngine.parsePace("0:00") == nil)
    }

    @Test func parsePaceRejectsSecondsAbove59() {
        #expect(ConversionEngine.parsePace("8:60") == nil)
        #expect(ConversionEngine.parsePace("8:90") == nil)
        #expect(ConversionEngine.parsePace("10:120") == nil)
    }

    // MARK: - Speed Parsing

    @Test func parseSpeedValid() {
        #expect(ConversionEngine.parseSpeed("10.5") == 10.5)
        #expect(ConversionEngine.parseSpeed("6") == 6.0)
    }

    @Test func parseSpeedInvalid() {
        #expect(ConversionEngine.parseSpeed("") == nil)
        #expect(ConversionEngine.parseSpeed("abc") == nil)
        #expect(ConversionEngine.parseSpeed("0") == nil)
    }

    // MARK: - Formatting

    @Test func formatSpeed() {
        #expect(ConversionEngine.formatSpeed(10.0) == "10.00")
        #expect(ConversionEngine.formatSpeed(7.567) == "7.57")
    }

    @Test func formatPace() {
        #expect(ConversionEngine.formatPace(8.5) == "8:30")
        #expect(ConversionEngine.formatPace(7.0) == "7:00")
        #expect(ConversionEngine.formatPace(6.25) == "6:15")
    }

    @Test func formatPaceInvalid() {
        #expect(ConversionEngine.formatPace(0) == nil)
        #expect(ConversionEngine.formatPace(-1) == nil)
        #expect(ConversionEngine.formatPace(.infinity) == nil)
    }

    // MARK: - Conversion

    @Test func paceToSpeed() {
        // 6:00/mi = 10 mph
        let speed = ConversionEngine.paceToSpeed(6.0)
        #expect(abs(speed - 10.0) < 0.001)
    }

    @Test func speedToPace() {
        // 10 mph = 6:00/mi
        let pace = ConversionEngine.speedToPace(10.0)
        #expect(abs(pace - 6.0) < 0.001)
    }

    @Test func unitConversionSpeed() {
        let kph = ConversionEngine.convertSpeedBetweenUnits(10.0, from: .mph, to: .kph)
        #expect(abs(kph - 16.0934) < 0.001)

        let mph = ConversionEngine.convertSpeedBetweenUnits(kph, from: .kph, to: .mph)
        #expect(abs(mph - 10.0) < 0.001)
    }

    @Test func unitConversionPace() {
        // 8:00/mi → should be ~4:58/km (shorter distance = less time)
        let perKm = ConversionEngine.convertPaceBetweenUnits(8.0, from: .mph, to: .kph)
        #expect(perKm < 8.0) // km pace should be shorter
        let backToMi = ConversionEngine.convertPaceBetweenUnits(perKm, from: .kph, to: .mph)
        #expect(abs(backToMi - 8.0) < 0.001)
    }

    @Test func sameUnitConversion() {
        #expect(ConversionEngine.convertSpeedBetweenUnits(10.0, from: .mph, to: .mph) == 10.0)
        #expect(ConversionEngine.convertPaceBetweenUnits(8.0, from: .kph, to: .kph) == 8.0)
    }

    @Test func convertPaceInputBetweenUnitsReformatsEquivalentPace() {
        #expect(ConversionEngine.convertPaceInput("8:00", from: .mph, to: .kph) == "4:58")
        #expect(ConversionEngine.convertPaceInput("4:58", from: .kph, to: .mph) == "8:00")
    }

    @Test func convertPaceComponentsBetweenUnitsPreservesValue() {
        let converted = ConversionEngine.convertPaceComponents(minutes: 8, seconds: 0, from: .mph, to: .kph)
        #expect(converted != nil)
        #expect(converted?.minutes == 4)
        #expect(converted?.seconds == 58)
    }

    @Test func convertDistanceInputBetweenUnitsReformatsEquivalentDistance() {
        #expect(ConversionEngine.convertDistanceInput("3.11", from: .mph, to: .kph) == "5.01")
        #expect(ConversionEngine.convertDistanceInput("5", from: .kph, to: .mph) == "3.11")
    }

    // MARK: - Full Conversion

    @Test func fullPaceToSpeed() {
        let result = ConversionEngine.convert(direction: .paceToSpeed, input: "6:00")
        #expect(result == "10.00")
    }

    @Test func fullSpeedToPace() {
        let result = ConversionEngine.convert(direction: .speedToPace, input: "10")
        #expect(result == "6:00")
    }

    @Test func fullConversionEmpty() {
        #expect(ConversionEngine.convert(direction: .paceToSpeed, input: "") == "")
        #expect(ConversionEngine.convert(direction: .speedToPace, input: "") == "")
    }

    // MARK: - Input Sanitization

    @Test func sanitizePaceInput() {
        let result = ConversionEngine.sanitizeInput(direction: .paceToSpeed, value: "8:3a0")
        #expect(result == "8:30")
    }

    @Test func sanitizeSpeedInput() {
        let result = ConversionEngine.sanitizeInput(direction: .speedToPace, value: "10.5abc")
        #expect(result == "10.5")
    }
}

struct ReviewRegressionTests {

    @Test func iOSAppBuildsWatchTargetWhenEmbeddingWatchContent() throws {
        let project = try testFileContents(
            "pace-to-mph.xcodeproj",
            "project.pbxproj"
        )

        let appTargetBlock = try #require(
            slice(
                in: project,
                from: "939A2E5B2F539927000B40F9 /* pace-to-mph */ = {",
                to: "939A2E682F539928000B40F9 /* pace-to-mphTests */ = {"
            )
        )

        #expect(appTargetBlock.contains("C0FFEE130000000000000013 /* Embed Watch Content */"))
        #expect(appTargetBlock.contains("C0FFEE150000000000000015 /* PBXTargetDependency */"))
    }

    @Test func favoriteButtonRemainsOutsideCombinedAccessibilityElement() throws {
        let contentView = try testFileContents("pace-to-mph", "ContentView.swift")
        let resultSection = try #require(
            slice(
                in: contentView,
                from: "// Result",
                to: ".sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.result)"
            )
        )

        let combineIndex = try #require(
            resultSection.range(of: ".accessibilityElement(children: .combine)")?.lowerBound
        )
        let favoriteIndex = try #require(
            resultSection.range(of: "if !viewModel.result.isEmpty {")?.lowerBound
        )

        #expect(combineIndex < favoriteIndex)
    }

    @Test func favoritesRowKeepsRemoveButtonFocusable() throws {
        let favoritesView = try testFileContents("pace-to-mph", "FavoritesView.swift")
        let rowSection = try #require(
            slice(
                in: favoritesView,
                from: "private func favoriteCard(_ fav: FavoriteConversion) -> some View {",
                to: "#Preview {"
            )
        )

        #expect(!rowSection.contains("""
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        """))
    }

    @Test func historyRowKeepsFavoriteButtonFocusable() throws {
        let historyView = try testFileContents("pace-to-mph", "HistoryView.swift")
        let rowSection = try #require(
            slice(
                in: historyView,
                from: "private func recordRow(_ record: ConversionRecord) -> some View {",
                to: "#Preview {"
            )
        )

        #expect(!rowSection.contains("""
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        """))
    }

    @Test func favoriteButtonsUseActionBasedLabels() throws {
        let contentView = try testFileContents("pace-to-mph", "ContentView.swift")
        let historyView = try testFileContents("pace-to-mph", "HistoryView.swift")

        #expect(!contentView.contains("Toggle favorite"))
        #expect(!historyView.contains("Toggle favorite"))
        #expect(contentView.contains("Add to favorites"))
        #expect(contentView.contains("Remove from favorites"))
        #expect(historyView.contains("Add to favorites"))
        #expect(historyView.contains("Remove from favorites"))
    }
}

private func testFileContents(_ pathComponents: String...) throws -> String {
    let fileURL = repoRootURL().appending(path: pathComponents.joined(separator: "/"))
    return try String(contentsOf: fileURL, encoding: .utf8)
}

private func repoRootURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func slice(in source: String, from start: String, to end: String) -> String? {
    guard
        let startRange = source.range(of: start),
        let endRange = source.range(of: end, range: startRange.lowerBound..<source.endIndex)
    else {
        return nil
    }

    return String(source[startRange.lowerBound..<endRange.lowerBound])
}
