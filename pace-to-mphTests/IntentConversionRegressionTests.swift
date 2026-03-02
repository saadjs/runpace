import AppIntents
import Testing
@testable import pace_to_mph

struct IntentConversionRegressionTests {
    private func assertResult(_ result: some ReturnsValue<String>, value: String, dialogContains: String) {
        #expect(result.value == value)
        #expect(String(describing: result).contains(dialogContains))
    }

    @Test func paceToSpeedIntentForMph() async throws {
        var intent = PaceToSpeedIntent()
        intent.pace = "8:00"
        intent.unit = .mph

        let result = try await intent.perform()
        assertResult(result, value: "7.50", dialogContains: "per mile")
    }

    @Test func paceToSpeedIntentForKph() async throws {
        var intent = PaceToSpeedIntent()
        intent.pace = "8:00"
        intent.unit = .kph

        let result = try await intent.perform()
        assertResult(result, value: "7.50", dialogContains: "per kilometer")
    }

    @Test func speedToPaceIntentForMph() async throws {
        var intent = SpeedToPaceIntent()
        intent.speed = 10
        intent.unit = .mph

        let result = try await intent.perform()
        assertResult(result, value: "6:00", dialogContains: "/mi")
    }

    @Test func speedToPaceIntentForKph() async throws {
        var intent = SpeedToPaceIntent()
        intent.speed = 12
        intent.unit = .kph

        let result = try await intent.perform()
        assertResult(result, value: "5:00", dialogContains: "/km")
    }
}
