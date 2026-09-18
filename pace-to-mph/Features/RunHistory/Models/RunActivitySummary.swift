import Foundation

struct RunActivitySummary: Equatable {
    let runCount: Int
    let distance: Double
    let duration: TimeInterval
    let previousRunCount: Int
    let previousDistance: Double
    let previousDuration: TimeInterval
    let cadence: RunCadence
    let unit: SpeedUnit
    let hasPreviousPeriod: Bool
    let longestDistance: Double
    let elevationGainMeters: Double
    let hasElevationData: Bool
    let elevationDataRunCount: Int
    let activeWeekCount: Int
    let elapsedWeekCount: Int
    let prHighlightTargets: [RunRecordTarget]
    /// True when the all-time longest run falls inside this scope.
    let setsLongestRun: Bool

    var prHighlightCount: Int { prHighlightTargets.count + (setsLongestRun ? 1 : 0) }

    var prHighlightNames: String {
        (prHighlightTargets.map(\.shortLabel) + (setsLongestRun ? [RunPRBadge.longestRunLabel] : []))
            .joined(separator: " · ")
    }

    var prHighlightAccessibilityNames: String {
        (prHighlightTargets.map(\.displayName) + (setsLongestRun ? ["Longest run"] : []))
            .joined(separator: ", ")
    }

    var distanceText: String {
        String(format: "%.1f", distance)
    }

    var averagePaceMinutes: Double? {
        guard distance > 0, duration > 0 else { return nil }
        return (duration / 60.0) / distance
    }

    var previousAveragePaceMinutes: Double? {
        guard previousDistance > 0, previousDuration > 0 else { return nil }
        return (previousDuration / 60.0) / previousDistance
    }

    var averagePaceText: String {
        averagePaceMinutes.flatMap(ConversionEngine.formatPace) ?? "—"
    }

    var distanceUnitLabel: String {
        unit == .mph ? "mi" : "km"
    }

    var distanceDeltaPercent: Double? {
        guard hasPreviousPeriod, previousDistance > 0 else { return nil }
        return (distance - previousDistance) / previousDistance
    }

    var runCountDelta: Int? {
        guard hasPreviousPeriod else { return nil }
        return runCount - previousRunCount
    }

    /// Positive means the current pace is faster, matching the positive/green
    /// semantics used by the other comparison metrics.
    var paceImprovementPercent: Double? {
        guard hasPreviousPeriod,
              let current = averagePaceMinutes,
              let previous = previousAveragePaceMinutes,
              previous > 0 else { return nil }
        return (previous - current) / previous
    }

    var longestRunText: String {
        let suffix = unit == .mph ? "mi" : "km"
        return "\(String(format: "%.1f", longestDistance)) \(suffix)"
    }

    var elevationGainText: String {
        guard hasElevationData else { return "—" }
        if unit == .mph {
            return "\(Int((elevationGainMeters * 3.28084).rounded()).formatted()) ft"
        }
        return "\(Int(elevationGainMeters.rounded()).formatted()) m"
    }

    var elevationGainLabel: String {
        guard hasElevationData else { return "No elevation data" }
        return elevationDataRunCount == runCount ? "Elevation gain" : "Partial elevation"
    }

    var consistencyText: String {
        "\(activeWeekCount)/\(elapsedWeekCount)"
    }
}

/// Average run frequency over a window. An average is only offered once the
/// window is meaningfully longer than the unit it averages over: "3 runs/mo"
/// across a single month is just the total wearing a different label.
struct RunCadence: Equatable {
    let runCount: Int
    let weeks: Double
    let months: Double

    var runsPerWeek: Double { runCount == 0 ? 0 : Double(runCount) / weeks }
    var runsPerMonth: Double { runCount == 0 ? 0 : Double(runCount) / months }

    var runsPerWeekText: String { String(format: "%.1f", runsPerWeek) }
    var runsPerMonthText: String { String(format: "%.1f", runsPerMonth) }

    var hasWeeklyAverage: Bool { runCount > 0 && weeks >= 1.5 }
    var hasMonthlyAverage: Bool { runCount > 0 && months >= 1.5 }

    /// Compact one-liner for the summary cards, or nil when the window is too
    /// short for either average to say anything the total doesn't.
    var averageText: String? {
        var parts: [String] = []
        if hasWeeklyAverage { parts.append("\(runsPerWeekText) runs/wk") }
        if hasMonthlyAverage { parts.append("\(runsPerMonthText) runs/mo") }
        guard parts.isEmpty == false else { return nil }
        return "Averaging " + parts.joined(separator: " · ")
    }

    var accessibilityText: String? {
        var parts: [String] = []
        if hasWeeklyAverage { parts.append("\(runsPerWeekText) runs per week") }
        if hasMonthlyAverage { parts.append("\(runsPerMonthText) runs per month") }
        guard parts.isEmpty == false else { return nil }
        return "Averaging " + parts.joined(separator: ", ")
    }
}
