import Foundation
import Testing
@testable import pace_to_mph

struct DefaultScreenSettingsTests {
    private func makeSettings(
        storedValue: String? = nil,
        function: String = #function
    ) -> (DefaultScreenSettings, UserDefaults, String, () -> Void) {
        let suiteName = "DefaultScreenSettingsTests.\(function).\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        let storageKey = "default-screen-test"
        if let storedValue {
            suite.set(storedValue, forKey: storageKey)
        }
        let settings = DefaultScreenSettings(userDefaults: suite, storageKey: storageKey)
        return (
            settings,
            suite,
            storageKey,
            { suite.removePersistentDomain(forName: suiteName) }
        )
    }

    @Test func converterIsTheDefault() {
        let (settings, _, _, cleanup) = makeSettings()
        defer { cleanup() }

        #expect(settings.defaultScreen == .converter)
    }

    @Test func selectedScreenPersists() {
        let (settings, suite, storageKey, cleanup) = makeSettings()
        defer { cleanup() }

        settings.defaultScreen = .runHistory

        #expect(suite.string(forKey: storageKey) == DefaultScreen.runHistory.rawValue)
        #expect(
            DefaultScreenSettings(userDefaults: suite, storageKey: storageKey).defaultScreen
                == .runHistory
        )
    }

    @Test func invalidStoredValueFallsBackToConverter() {
        let (settings, _, _, cleanup) = makeSettings(storedValue: "unknown-screen")
        defer { cleanup() }

        #expect(settings.defaultScreen == .converter)
    }

    @Test func everyUserFacingToolCanBeSelected() {
        #expect(DefaultScreen.allCases == [
            .converter,
            .raceCalculator,
            .evenSplits,
            .negativeSplits,
            .runHistory,
            .favorites,
            .referenceTable,
        ])
    }
}
