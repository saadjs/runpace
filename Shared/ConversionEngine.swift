import Foundation

enum ConversionDirection: String, CaseIterable {
    case paceToSpeed
    case speedToPace

    var label: String {
        switch self {
        case .paceToSpeed: return "Pace → Speed"
        case .speedToPace: return "Speed → Pace"
        }
    }
}

enum SpeedUnit: String, CaseIterable {
    case mph
    case kph

    var label: String { rawValue.uppercased() }

    var paceLabel: String {
        switch self {
        case .mph: return "/mi"
        case .kph: return "/km"
        }
    }

    var speedLabel: String {
        switch self {
        case .mph: return "MPH"
        case .kph: return "KM/H"
        }
    }
}

nonisolated enum ConversionEngine {
    static let kmPerMile: Double = 1.60934

    // MARK: - Parsing

    /// Parse a pace string like "8:30" or "8.5" into total minutes
    static func parsePace(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let normalized = trimmed.filter { $0.isNumber || $0 == ":" || $0 == "." }
        guard !normalized.isEmpty else { return nil }

        let segments = normalized.split(separator: ":", maxSplits: 1)

        if segments.count == 1 {
            guard let decimal = Double(String(segments[0])), decimal.isFinite, decimal > 0 else {
                return nil
            }
            return decimal
        }

        if segments.count == 2 {
            guard let minutes = Double(String(segments[0])),
                  let seconds = Double(String(segments[1])),
                  minutes.isFinite, seconds.isFinite,
                  seconds >= 0, seconds < 60 else {
                return nil
            }
            let total = minutes + seconds / 60.0
            return total > 0 ? total : nil
        }

        return nil
    }

    /// Parse a speed string like "10.5" into a Double
    static func parseSpeed(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let normalized = trimmed.filter { $0.isNumber || $0 == "." }
        guard !normalized.isEmpty else { return nil }
        guard let parsed = Double(normalized), parsed.isFinite, parsed > 0 else { return nil }
        return parsed
    }

    // MARK: - Formatting

    /// Format a speed value to 2 decimal places
    static func formatSpeed(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// Format minutes-per-unit as "mm:ss"
    static func formatPace(_ minutesPerUnit: Double) -> String? {
        guard minutesPerUnit.isFinite, minutesPerUnit > 0 else { return nil }

        let totalSeconds = Int(round(minutesPerUnit * 60))
        var minutes = totalSeconds / 60
        var seconds = totalSeconds % 60

        if seconds == 60 {
            minutes += 1
            seconds = 0
        }

        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    // MARK: - Conversion

    static func paceToSpeed(_ paceMinutes: Double) -> Double {
        60.0 / paceMinutes
    }

    static func speedToPace(_ speed: Double) -> Double {
        60.0 / speed
    }

    static func convertPaceBetweenUnits(_ paceMinutes: Double, from: SpeedUnit, to: SpeedUnit) -> Double {
        guard from != to else { return paceMinutes }
        return from == .mph ? paceMinutes / kmPerMile : paceMinutes * kmPerMile
    }

    static func convertDistanceBetweenUnits(_ distance: Double, from: SpeedUnit, to: SpeedUnit) -> Double {
        guard from != to else { return distance }
        return from == .mph ? distance * kmPerMile : distance / kmPerMile
    }

    static func convertSpeedBetweenUnits(_ speed: Double, from: SpeedUnit, to: SpeedUnit) -> Double {
        guard from != to else { return speed }
        return from == .mph ? speed * kmPerMile : speed / kmPerMile
    }

    /// Convert a time-per-distance delta (e.g. drop seconds per split) between unit systems.
    static func convertDropSecondsBetweenUnits(_ seconds: Double, from: SpeedUnit, to: SpeedUnit) -> Double {
        guard from != to else { return seconds }
        return from == .mph ? seconds / kmPerMile : seconds * kmPerMile
    }

    static func convertPaceInput(_ paceInput: String, from: SpeedUnit, to: SpeedUnit) -> String {
        guard from != to, let pace = parsePace(paceInput) else { return paceInput }
        let converted = convertPaceBetweenUnits(pace, from: from, to: to)
        return formatPace(converted) ?? paceInput
    }

    static func convertPaceComponents(minutes: Int, seconds: Int, from: SpeedUnit, to: SpeedUnit) -> (minutes: Int, seconds: Int)? {
        guard minutes >= 0, seconds >= 0, seconds < 60 else { return nil }
        let paceMinutes = Double(minutes) + Double(seconds) / 60.0
        guard paceMinutes > 0 else { return nil }

        let converted = convertPaceBetweenUnits(paceMinutes, from: from, to: to)
        let totalSeconds = Int(round(converted * 60.0))
        guard totalSeconds > 0 else { return nil }

        return (minutes: totalSeconds / 60, seconds: totalSeconds % 60)
    }

    static func convertDistanceInput(_ distanceInput: String, from: SpeedUnit, to: SpeedUnit) -> String {
        guard from != to, let distance = parseSpeed(distanceInput) else { return distanceInput }
        let converted = convertDistanceBetweenUnits(distance, from: from, to: to)
        return formatDecimalInput(converted)
    }

    // MARK: - Input Sanitization

    static func sanitizeInput(direction: ConversionDirection, value: String) -> String {
        switch direction {
        case .paceToSpeed:
            return value.filter { $0.isNumber || $0 == ":" || $0 == "." }
        case .speedToPace:
            return value.filter { $0.isNumber || $0 == "." }
        }
    }

    // MARK: - Full Conversion

    /// Perform the full conversion given direction, input string. Returns formatted result or empty string.
    static func convert(direction: ConversionDirection, input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }

        switch direction {
        case .paceToSpeed:
            guard let paceMinutes = parsePace(trimmed) else { return "" }
            let speed = paceToSpeed(paceMinutes)
            return formatSpeed(speed)
        case .speedToPace:
            guard let speedValue = parseSpeed(trimmed) else { return "" }
            let paceMinutes = speedToPace(speedValue)
            return formatPace(paceMinutes) ?? ""
        }
    }

    private static func formatDecimalInput(_ value: Double) -> String {
        var formatted = String(format: "%.2f", value)

        while formatted.contains(".") && formatted.last == "0" {
            formatted.removeLast()
        }

        if formatted.last == "." {
            formatted.removeLast()
        }

        return formatted
    }
}
