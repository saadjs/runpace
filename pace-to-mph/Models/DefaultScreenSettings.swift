import Foundation
import Observation

enum DefaultScreen: String, CaseIterable, Hashable, Identifiable {
    case converter
    case raceCalculator
    case evenSplits
    case negativeSplits
    case runHistory
    case favorites
    case referenceTable

    var id: String { rawValue }

    var label: String {
        switch self {
        case .converter: return "Converter"
        case .raceCalculator: return "Race Calculator"
        case .evenSplits: return "Even Splits"
        case .negativeSplits: return "Negative Splits"
        case .runHistory: return "Run History"
        case .favorites: return "Favorites"
        case .referenceTable: return "Reference Table"
        }
    }

    var systemImage: String {
        switch self {
        case .converter: return "arrow.left.arrow.right"
        case .raceCalculator: return "flag.checkered"
        case .evenSplits: return "chart.bar"
        case .negativeSplits: return "arrow.down.right"
        case .runHistory: return "figure.run"
        case .favorites: return "star"
        case .referenceTable: return "table"
        }
    }
}

@Observable
final class DefaultScreenSettings {
    static let shared = DefaultScreenSettings()
    static let storageKey = "defaultScreen"

    private let userDefaults: UserDefaults
    private let storageKey: String

    var defaultScreen: DefaultScreen {
        didSet {
            guard defaultScreen != oldValue else { return }
            userDefaults.set(defaultScreen.rawValue, forKey: storageKey)
        }
    }

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = DefaultScreenSettings.storageKey
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        let rawValue = userDefaults.string(forKey: storageKey) ?? ""
        self.defaultScreen = DefaultScreen(rawValue: rawValue) ?? .converter
    }
}
