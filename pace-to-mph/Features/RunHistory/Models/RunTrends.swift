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

struct RunEffortPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    /// Heartbeats spent per mile/kilometre on this run.
    let beats: Double
    let heartRate: Int
    let paceText: String
    let distanceValueText: String

    var beatsText: String { Int(beats.rounded()).formatted() }
}

/// Effort runs the opposite way to speed: fewer beats per mile is better, so a
/// falling line is the good one.
enum RunEffortTrendDirection: Equatable {
    case improving
    case steady
    case declining
    case insufficient
}

/// Heartbeats spent per mile/kilometre for every run in scope that recorded a
/// heart rate, plus a least squares best-fit line. It pairs effort with output,
/// so holding pace at a calmer heart rate shows up as progress where a plain
/// speed chart would read as flat.
struct RunEffortTrend: Equatable {
    let points: [RunEffortPoint]
    let fittedStart: Double?
    let fittedEnd: Double?
    let averageBeats: Double
    let changeOverPeriod: Double
    let direction: RunEffortTrendDirection
    let unit: SpeedUnit
    /// Runs in scope with no heart rate recorded, so the card can say what it
    /// had to leave out rather than quietly plotting fewer runs than the user
    /// knows they ran.
    let runsWithoutHeartRate: Int

    var hasData: Bool { points.isEmpty == false }
    var runCount: Int { points.count }
    var hasTrendLine: Bool { fittedStart != nil && fittedEnd != nil }
    var averageBeatsText: String { Int(averageBeats.rounded()).formatted() }
    var changeMagnitudeText: String { Int(abs(changeOverPeriod).rounded()).formatted() }
}
