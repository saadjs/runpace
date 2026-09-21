import Foundation

extension RunHistoryStats {
    /// Plots every run's average speed in scope and fits a least squares trend
    /// line. The line is drawn at >=2 runs, but a faster/slower *verdict* is only
    /// claimed at >=5 runs with a wide "steady" band, since run-to-run scatter is
    /// large and a confident-but-wrong direction is worse than none.
    static func speedTrend(
        from runs: [RunWorkout],
        scope: RunTrendScope,
        unit: SpeedUnit,
        referenceDate: Date = Date()
    ) -> RunSpeedTrend {
        let lower = scope.lowerBound(from: referenceDate, calendar: calendar)
        let scoped: [RunWorkout]
        if let lower {
            scoped = runs.filter { $0.startDate >= lower && $0.startDate <= referenceDate }
        } else {
            scoped = runs
        }
        return speedTrend(forRuns: scoped, unit: unit)
    }


    private static func speedTrend(forRuns runs: [RunWorkout], unit: SpeedUnit) -> RunSpeedTrend {
        let points = runs
            .filter { $0.duration > 0 && $0.distanceMeters > 0 }
            .sorted { $0.startDate < $1.startDate }
            .map { run -> RunChartPoint in
                let speed = unit == .mph ? run.averageSpeedMph : run.averageSpeedKph
                let pace = unit == .mph ? run.paceMinutesPerMile : run.paceMinutesPerKilometer
                let paceText = pace.flatMap { ConversionEngine.formatPace($0) } ?? "--"
                let distance = unit == .mph ? run.distanceMiles : run.distanceKilometers
                let distanceValueText = String(format: "%.2f", distance)
                return RunChartPoint(id: run.id.uuidString, date: run.startDate, speed: speed, paceText: paceText, distanceValueText: distanceValueText, avgHeartRate: run.avgHeartRate)
            }

        let speeds = points.map(\.speed)
        let average = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)

        var trendStart: RunChartPoint?
        var trendEnd: RunChartPoint?
        var change = 0.0

        if let first = points.first, let last = points.last,
           let fit = linearFit(dates: points.map(\.date), values: speeds) {
            change = fit.change
            trendStart = RunChartPoint(id: "trend-start", date: first.date, speed: fit.start, paceText: "", distanceValueText: "", avgHeartRate: nil)
            trendEnd = RunChartPoint(id: "trend-end", date: last.date, speed: fit.end, paceText: "", distanceValueText: "", avgHeartRate: nil)
        }

        let direction: RunTrendDirection
        if points.count < 5 || trendEnd == nil {
            direction = .insufficient
        } else {
            // Steady band: ~4% of average speed, with an absolute floor so it stays
            // forgiving at low speeds. Anything inside reads as "holding steady".
            let band = max(average * 0.04, unit == .mph ? 0.1 : 0.16)
            if abs(change) < band {
                direction = .steady
            } else {
                direction = change > 0 ? .faster : .slower
            }
        }

        return RunSpeedTrend(
            points: points,
            trendStart: trendStart,
            trendEnd: trendEnd,
            averageSpeed: average,
            changeOverPeriod: change,
            direction: direction,
            unit: unit
        )
    }

    /// One Speed Trend chart per named distance (5K, 10K, …): runs are bucketed
    /// by distance (±5% band) so each chart compares like-for-like efforts and
    /// the trend line isn't confounded by whether you ran short or long lately.
    /// A distance only appears once it has at least 2 runs in scope, and only
    /// when it's relevant to the active unit (no "1 KM" chart for mph users).
    /// Returned ascending by distance for a stable picker order.
    static func speedTrendsByDistance(
        from runs: [RunWorkout],
        scope: RunTrendScope,
        unit: SpeedUnit,
        referenceDate: Date = Date()
    ) -> [RunDistanceTrend] {
        let lower = scope.lowerBound(from: referenceDate, calendar: calendar)
        let scoped: [RunWorkout]
        if let lower {
            scoped = runs.filter { $0.startDate >= lower && $0.startDate <= referenceDate }
        } else {
            scoped = runs
        }

        return RunRecordTarget.allCases
            .filter { $0.isVisible(in: unit) }
            .compactMap { target in
                let bucket = scoped.filter { target.containsDistance($0.distanceMeters) }
                // Count valid chart points, not raw runs: a zero-distance/zero-duration
                // run is dropped by speedTrend, so gating on bucket.count could surface
                // a "trend" with a single plotted point.
                let trend = speedTrend(forRuns: bucket, unit: unit)
                guard trend.runCount >= 2 else { return nil }
                return RunDistanceTrend(target: target, trend: trend)
            }
    }

    /// Plots how far each run in scope went and fits a least squares line, so
    /// "are my runs getting longer?" reads at a glance. Easy days and long runs
    /// swing distance far more than speed, and that mix alone can tilt the line,
    /// so a longer/shorter verdict also needs the slope to clear one standard
    /// error; a tilt that doesn't is reported as unclear rather than steady.
    static func runLengthTrend(
        from runs: [RunWorkout],
        scope: RunTrendScope,
        unit: SpeedUnit,
        referenceDate: Date = Date()
    ) -> RunLengthTrend {
        let lower = scope.lowerBound(from: referenceDate, calendar: calendar)
        let points = runs
            .filter { run in
                run.distanceMeters > 0 && run.startDate <= referenceDate
                    && (lower.map { run.startDate >= $0 } ?? true)
            }
            .sorted { $0.startDate < $1.startDate }
            .map { run in
                let pace = unit == .mph ? run.paceMinutesPerMile : run.paceMinutesPerKilometer
                return RunLengthPoint(
                    id: run.id.uuidString,
                    date: run.startDate,
                    distance: unit == .mph ? run.distanceMiles : run.distanceKilometers,
                    duration: run.duration,
                    paceText: run.duration > 0 ? pace.flatMap(ConversionEngine.formatPace) ?? "--" : "--"
                )
            }

        let distances = points.map(\.distance)
        let average = distances.isEmpty ? 0 : distances.reduce(0, +) / Double(distances.count)
        let fit = linearFit(dates: points.map(\.date), values: distances)
        let change = fit?.change ?? 0

        let direction: RunLengthTrendDirection
        if let fit, points.count >= 5 {
            let band = max(average * 0.10, unit == .mph ? 0.25 : 0.4)
            if abs(change) < band {
                direction = .steady
            } else if fit.tStatistic < 1 {
                direction = .unclear
            } else {
                direction = change > 0 ? .longer : .shorter
            }
        } else {
            direction = .insufficient
        }

        return RunLengthTrend(
            points: points,
            fittedStart: fit?.start,
            fittedEnd: fit?.end,
            averageDistance: average,
            changeOverPeriod: change,
            direction: direction,
            unit: unit
        )
    }

    /// Least squares line through the samples, as its fitted values at the
    /// first and last sample dates. Nil below two samples or when every sample
    /// shares one date.
    private static func linearFit(dates: [Date], values: [Double]) -> LinearFit? {
        guard dates.count >= 2, dates.count == values.count, let origin = dates.first else { return nil }
        let xs = dates.map { $0.timeIntervalSince(origin) / 86_400.0 }
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = values.reduce(0, +) / n
        let sxx = xs.reduce(0) { $0 + ($1 - meanX) * ($1 - meanX) }
        guard sxx > 0 else { return nil }
        let sxy = zip(xs, values).reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        let slope = sxy / sxx
        let intercept = meanY - slope * meanX
        let squaredResiduals = zip(xs, values).reduce(0) { sum, sample in
            let residual = sample.1 - (intercept + slope * sample.0)
            return sum + residual * residual
        }
        let slopeError = n > 2 ? (squaredResiduals / (n - 2) / sxx).squareRoot() : .infinity
        return LinearFit(
            start: intercept,
            end: intercept + slope * (xs.last ?? 0),
            tStatistic: slopeError > 0 ? abs(slope) / slopeError : .infinity
        )
    }
}
private struct LinearFit {
    let start: Double
    let end: Double
    /// Slope over its standard error: how clearly the tilt stands out from the scatter.
    let tStatistic: Double

    var change: Double { end - start }
}
