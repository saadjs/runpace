import Foundation

struct RunPersonalRecord: Identifiable, Equatable {
    let id: String
    let target: RunRecordTarget
    let unit: SpeedUnit
    let runID: UUID
    let speed: Double
    let paceText: String
    let deltaSpeed: Double
    let achievedDate: Date

    var speedText: String {
        String(format: "%.2f", speed)
    }
}

struct RunRecordMilestone: Identifiable, Equatable {
    let id: UUID
    let target: RunRecordTarget
    let unit: SpeedUnit
    let date: Date
    let speed: Double
    let durationMinutes: Double
    /// True when the effort was extrapolated from a longer run at that run's
    /// average pace, rather than actually raced at this distance.
    let isEstimated: Bool
    let previousDate: Date?
    let previousDurationMinutes: Double?

    var paceMinutes: Double { durationMinutes / target.distance(for: unit) }
    var timeText: String { RunHistoryFormatters.duration(durationMinutes * 60) }
    var paceText: String { ConversionEngine.formatPace(paceMinutes) ?? "--" }
    var speedText: String { String(format: "%.2f", speed) }

    var previousTimeText: String? {
        guard let previousDurationMinutes else { return nil }
        return RunHistoryFormatters.duration(previousDurationMinutes * 60)
    }

    var improvementSeconds: Double? {
        guard let previousDurationMinutes else { return nil }
        return (previousDurationMinutes - durationMinutes) * 60
    }

    var paceImprovementSeconds: Double? {
        guard let previousDurationMinutes else { return nil }
        return (previousDurationMinutes - durationMinutes) * 60 / target.distance(for: unit)
    }

    var improvementText: String? {
        guard let improvementSeconds, improvementSeconds > 0 else { return nil }
        return "\(RunHistoryFormatters.gap(improvementSeconds)) faster"
    }

    var paceImprovementText: String? {
        guard let paceImprovementSeconds, paceImprovementSeconds > 0 else { return nil }
        return "\(RunHistoryFormatters.gap(paceImprovementSeconds))\(unit.paceLabel) quicker"
    }

    var daysSincePrevious: Int? {
        guard let previousDate else { return nil }
        return RunHistoryStats.calendar.dateComponents([.day], from: previousDate, to: date).day
    }

    var previousStoodText: String? {
        daysSincePrevious.flatMap(RunHistoryFormatters.stood(days:))
    }
}

struct RunLongestRunMilestone: Identifiable, Equatable {
    let id: UUID
    let unit: SpeedUnit
    let date: Date
    let distanceMeters: Double
    let duration: TimeInterval
    let previousDate: Date?
    let previousDistanceMeters: Double?

    var distance: Double { RunHistoryFormatters.distance(meters: distanceMeters, unit: unit) }
    var distanceValueText: String { String(format: "%.2f", distance) }
    var distanceText: String { "\(distanceValueText) \(unit.distanceLabel)" }
    var timeText: String { duration > 0 ? RunHistoryFormatters.duration(duration) : "--" }

    var paceText: String {
        guard duration > 0, distance > 0 else { return "--" }
        return ConversionEngine.formatPace((duration / 60.0) / distance) ?? "--"
    }

    var previousDistanceText: String? {
        guard let previousDistanceMeters else { return nil }
        let previous = RunHistoryFormatters.distance(meters: previousDistanceMeters, unit: unit)
        return "\(String(format: "%.2f", previous)) \(unit.distanceLabel)"
    }

    /// How much farther this run went than the record it replaced, in the unit's distance.
    var extraDistance: Double? {
        guard let previousDistanceMeters else { return nil }
        return RunHistoryFormatters.distance(meters: distanceMeters - previousDistanceMeters, unit: unit)
    }

    var extraDistanceText: String? {
        guard let extraDistance, extraDistance > 0 else { return nil }
        return "\(String(format: "%.2f", extraDistance)) \(unit.distanceLabel) farther"
    }

    var daysSincePrevious: Int? {
        guard let previousDate else { return nil }
        return RunHistoryStats.calendar.dateComponents([.day], from: previousDate, to: date).day
    }

    var previousStoodText: String? {
        daysSincePrevious.flatMap(RunHistoryFormatters.stood(days:))
    }
}

/// A record tag on a run in the Runs list.
enum RunPRBadge: Hashable, Identifiable {
    case record(RunRecordTarget)
    case longestRun

    static let longestRunLabel = "LONGEST"

    var id: String {
        switch self {
        case .record(let target): return target.id
        case .longestRun: return "longest-run"
        }
    }

    var title: String {
        switch self {
        case .record(let target): return "\(target.shortLabel) PR"
        case .longestRun: return Self.longestRunLabel
        }
    }

    var accessibilityName: String {
        switch self {
        case .record(let target): return "\(target.displayName) personal record"
        case .longestRun: return "Longest run"
        }
    }
}
