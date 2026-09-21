import Foundation

enum RunRecordTarget: String, CaseIterable, Identifiable {
    case oneMile
    case oneKilometer
    case fiveKilometers
    case tenKilometers
    case halfMarathon
    case marathon

    var id: String { rawValue }

    var meters: Double {
        switch self {
        case .oneMile:
            return 1609.34
        case .oneKilometer:
            return 1000
        case .fiveKilometers:
            return 5000
        case .tenKilometers:
            return 10000
        case .halfMarathon:
            return 21097.5
        case .marathon:
            return 42195
        }
    }

    var shortLabel: String {
        switch self {
        case .oneMile:
            return "1 MILE"
        case .oneKilometer:
            return "1 KM"
        case .fiveKilometers:
            return "5K"
        case .tenKilometers:
            return "10K"
        case .halfMarathon:
            return "HALF"
        case .marathon:
            return "MARA"
        }
    }

    var distanceCopy: String {
        switch self {
        case .oneMile:
            return "a mile"
        case .oneKilometer:
            return "a kilometer"
        case .fiveKilometers:
            return "5K"
        case .tenKilometers:
            return "10K"
        case .halfMarathon:
            return "a half marathon"
        case .marathon:
            return "a marathon"
        }
    }

    var displayName: String {
        switch self {
        case .oneMile:
            return "1 Mile"
        case .oneKilometer:
            return "1 KM"
        case .fiveKilometers:
            return "5K"
        case .tenKilometers:
            return "10K"
        case .halfMarathon:
            return "Half Marathon"
        case .marathon:
            return "Marathon"
        }
    }

    /// A run counts toward this distance when it's within ±5% of the nominal
    /// distance. Runs in the gaps still contribute to All Runs and Volume, but
    /// are not presented as a named-distance effort.
    func containsDistance(_ meters: Double) -> Bool {
        abs(meters - self.meters) <= self.meters * 0.05
    }

    func matchingRangeText(in unit: SpeedUnit) -> String {
        let nominal = distance(for: unit)
        let suffix = unit == .mph ? "mi" : "km"
        return String(format: "%.2f–%.2f %@", nominal * 0.95, nominal * 1.05, suffix)
    }

    func isVisible(in unit: SpeedUnit) -> Bool {
        switch (self, unit) {
        case (.oneMile, .kph), (.oneKilometer, .mph):
            return false
        default:
            return true
        }
    }

    func distance(for unit: SpeedUnit) -> Double {
        switch unit {
        case .mph:
            return meters / 1609.34
        case .kph:
            return meters / 1000.0
        }
    }
}
