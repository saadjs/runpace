import Foundation

struct RunHistoryStats {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    static func summary(from runs: [RunWorkout], unit: SpeedUnit) -> RunHistorySummary {
        let totalDistance = runs.reduce(0.0) { partial, run in
            partial + (unit == .mph ? run.distanceMiles : run.distanceKilometers)
        }
        let totalDuration = runs.reduce(0.0) { $0 + $1.duration }
        let averageSpeed = totalDuration > 0 ? totalDistance / (totalDuration / 3600.0) : 0

        return RunHistorySummary(
            runCount: runs.count,
            distanceText: RunHistoryFormatters.decimal(totalDistance, fractionDigits: 1),
            durationText: RunHistoryFormatters.duration(totalDuration),
            averageSpeedText: RunHistoryFormatters.decimal(averageSpeed, fractionDigits: 2)
        )
    }

    /// How often the runner actually runs, as an average per week and per month
    /// over an explicit window. Totals alone can't answer "am I running enough?" —
    /// 40 runs reads very differently over a month than over a year.
    ///
    /// The window is clipped to `referenceDate` (counting the unfinished
    /// remainder of this month would understate cadence) and floored at one
    /// week / one month, so a three-day-old window can't claim 7 runs a week.
    /// Pass `nil` for all time, which measures from the first run.
    static func cadence(
        from runs: [RunWorkout],
        in interval: DateInterval?,
        referenceDate: Date = Date()
    ) -> RunCadence {
        let windowStart = interval?.start ?? runs.map(\.startDate).min()
        let windowEnd = min(interval?.end ?? referenceDate, referenceDate)

        guard let windowStart, windowEnd > windowStart else {
            return RunCadence(runCount: runs.count, weeks: 1, months: 1)
        }

        let days = windowEnd.timeIntervalSince(windowStart) / 86_400
        return RunCadence(
            runCount: runs.count,
            weeks: max(days / 7, 1),
            months: max(days / 30.436_875, 1)
        )
    }

    static func totalDistance(_ runs: [RunWorkout], unit: SpeedUnit) -> Double {
        runs.reduce(0.0) { partial, run in
            partial + (unit == .mph ? run.distanceMiles : run.distanceKilometers)
        }
    }
}
