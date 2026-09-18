import Testing
@testable import pace_to_mph

@MainActor
struct RaceTimeCalculationTests {
    @Test func metricPaceProducesFinishTimeAndSpeed() {
        let result = calculation(pace: "5:00", unit: .kph)
        #expect(result.finishTimeText == "25:00")
        #expect(result.speedText == "12.00")
    }

    @Test func imperialPaceUsesRaceDistanceInMiles() {
        let result = calculation(pace: "8:00", unit: .mph)
        #expect(result.finishTimeText == "24:51")
        #expect(result.speedText == "7.50")
    }

    @Test func finishTimeProducesPaceInEitherUnit() {
        let result = calculation(time: "25:00", unit: .kph)
        #expect(result.hasTargetPaceResult)
        #expect(result.paceText(unit: .kph) == "5:00")
        #expect(result.paceText(unit: .mph) == "8:03")
        #expect(result.speedTextForTargetPace(unit: .kph) == "12.00")
    }

    @Test func customDistanceIsInterpretedInSelectedUnit() {
        let result = calculation(pace: "8:00", time: "24:00", unit: .mph, distance: .custom, custom: "3")
        #expect(result.finishTimeText == "24:00")
        #expect(result.paceText(unit: .mph) == "8:00")
        #expect(result.paceText(unit: .kph) == "4:58")
    }

    @Test(arguments: ["", "abc", "0", "-2"])
    func invalidCustomDistanceLeavesResultsEmpty(input: String) {
        let result = calculation(pace: "8:00", time: "24:00", distance: .custom, custom: input)
        #expect(result.finishTimeText.isEmpty)
        #expect(!result.hasTargetPaceResult)
        #expect(result.paceText(unit: .mph).isEmpty)
        // The speed readout depends on pace alone, even before distance is entered.
        #expect(result.speedText == "7.50")
    }

    @Test(arguments: ["", "abc", "0:00", "1:99:00"])
    func invalidFinishTimeLeavesTargetPaceEmpty(input: String) {
        let result = calculation(time: input)
        #expect(!result.hasTargetPaceResult)
        #expect(result.paceText(unit: .mph).isEmpty)
        #expect(result.speedTextForTargetPace(unit: .mph).isEmpty)
    }

    @Test func standardDistanceIgnoresStaleCustomInput() {
        let result = calculation(pace: "5:00", unit: .kph, custom: "bad input")
        #expect(result.finishTimeText == "25:00")
    }

    @Test func durationOverAnHourKeepsHours() {
        let result = calculation(pace: "5:00", time: "3:30:00", unit: .kph, distance: .marathon)
        #expect(result.finishTimeText == "3:30:59")
        #expect(result.paceText(unit: .kph) == "4:59")
    }

    private func calculation(
        pace: String = "",
        time: String = "",
        unit: SpeedUnit = .mph,
        distance: RaceCalculator.Distance = .fiveK,
        custom: String = ""
    ) -> RaceTimeCalculation {
        RaceTimeCalculation(
            paceInput: pace,
            timeInput: time,
            selectedUnit: unit,
            selectedDistance: distance,
            customDistanceInput: custom
        )
    }
}
