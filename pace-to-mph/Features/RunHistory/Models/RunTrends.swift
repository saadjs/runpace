import Foundation

struct RunPaceTrendPoint: Identifiable, Equatable {
    let id: String
    let periodStart: Date
    let paceMinutes: Double
    let runCount: Int
    let distance: Double

    var paceText: String {
        ConversionEngine.formatPace(paceMinutes) ?? "—"
    }
}

struct RunVolumeBar: Identifiable, Equatable {
    let id: String
    let periodStart: Date
    let distance: Double
    let label: String
    let runCount: Int
    let averagePaceMinutes: Double

    var paceText: String {
        ConversionEngine.formatPace(averagePaceMinutes) ?? "—"
    }
}

struct RunChartPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let speed: Double
    let paceText: String
    let distanceValueText: String
    let avgHeartRate: Int?
}

enum RunTrendDirection: Equatable {
    case faster
    case steady
    case slower
    case insufficient
}

/// Overall speed trend: one point per run (its average speed) plus a least
/// squares best-fit line so the direction reads at a glance.
struct RunSpeedTrend: Equatable {
    let points: [RunChartPoint]
    let trendStart: RunChartPoint?
    let trendEnd: RunChartPoint?
    let averageSpeed: Double
    let changeOverPeriod: Double
    let direction: RunTrendDirection
    let unit: SpeedUnit

    var hasData: Bool { points.isEmpty == false }
    var runCount: Int { points.count }
    var averageSpeedText: String { String(format: "%.2f", averageSpeed) }
    var changeMagnitudeText: String { String(format: "%.2f", abs(changeOverPeriod)) }
}

struct RunLengthPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let distance: Double
    let duration: TimeInterval
    let paceText: String

    var distanceValueText: String { String(format: "%.2f", distance) }
}

enum RunLengthTrendDirection: Equatable {
    case longer
    case steady
    case shorter
    /// The line tilts, but run-to-run scatter is too wide to call it.
    case unclear
    case insufficient
}

/// Distance of every run in scope plus a least squares best-fit line, so the
/// Trends tab can say whether runs are getting longer.
struct RunLengthTrend: Equatable {
    let points: [RunLengthPoint]
    let fittedStart: Double?
    let fittedEnd: Double?
    let averageDistance: Double
    let changeOverPeriod: Double
    let direction: RunLengthTrendDirection
    let unit: SpeedUnit

    var hasData: Bool { points.isEmpty == false }
    var runCount: Int { points.count }
    var hasTrendLine: Bool { fittedStart != nil && fittedEnd != nil }
    var averageDistanceText: String { String(format: "%.1f", averageDistance) }
    var changeMagnitudeText: String { String(format: "%.1f", abs(changeOverPeriod)) }
}

/// A Speed Trend scoped to a single named distance, used to drive the Trends
/// tab's per-distance chart and its distance picker.
struct RunDistanceTrend: Identifiable, Equatable {
    let target: RunRecordTarget
    let trend: RunSpeedTrend

    var id: String { target.id }
}
