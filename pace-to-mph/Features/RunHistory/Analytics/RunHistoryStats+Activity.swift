import Foundation

extension RunHistoryStats {
    /// `records` lets a caller that already computed the all-time PRs hand them
    /// in rather than paying for a second full scan; omit it and they are
    /// derived here.
    static func activitySummary(
        from runs: [RunWorkout],
        scope: RunTrendScope,
        unit: SpeedUnit,
        referenceDate: Date = Date(),
        records: [RunPersonalRecord]? = nil
    ) -> RunActivitySummary {
        let lower = scope.lowerBound(from: referenceDate, calendar: calendar)
        let previousLower = scope.previousLowerBound(from: referenceDate, calendar: calendar)

        let currentRuns: [RunWorkout]
        if let lower {
            currentRuns = runs.filter { $0.startDate >= lower && $0.startDate <= referenceDate }
        } else {
            currentRuns = runs
        }

        let previousRuns: [RunWorkout]
        if let lower, let previousLower {
            previousRuns = runs.filter { $0.startDate >= previousLower && $0.startDate < lower }
        } else {
            previousRuns = []
        }

        let distance = totalDistance(currentRuns, unit: unit)
        let duration = currentRuns.reduce(0.0) { $0 + $1.duration }
        let previousDistance = totalDistance(previousRuns, unit: unit)
        let previousDuration = previousRuns.reduce(0.0) { $0 + $1.duration }

        let window = lower.map { DateInterval(start: $0, end: referenceDate) }
        let currentCadence = cadence(from: currentRuns, in: window, referenceDate: referenceDate)
        let activeWeekCount = Set(currentRuns.map { weekStart(containing: $0.startDate) }).count
        let elapsedWeekCount = calendarWeekCount(
            from: window?.start ?? currentRuns.map(\.startDate).min(),
            through: referenceDate
        )
        let currentRunIDs = Set(currentRuns.map(\.id))
        let allRecords = records ?? personalRecords(from: runs, unit: unit, referenceDate: referenceDate)
        let prHighlightTargets = allRecords
            .filter { currentRunIDs.contains($0.runID) }
            .map(\.target)
        let setsLongestRun = longestRun(from: runs).map { currentRunIDs.contains($0.id) } ?? false
        let elevations = currentRuns.compactMap(\.elevationGainMeters)

        return RunActivitySummary(
            runCount: currentRuns.count,
            distance: distance,
            duration: duration,
            previousRunCount: previousRuns.count,
            previousDistance: previousDistance,
            previousDuration: previousDuration,
            cadence: currentCadence,
            unit: unit,
            hasPreviousPeriod: scope != .allTime,
            longestDistance: currentRuns.map { unit == .mph ? $0.distanceMiles : $0.distanceKilometers }.max() ?? 0,
            elevationGainMeters: elevations.reduce(0, +),
            hasElevationData: elevations.isEmpty == false,
            elevationDataRunCount: elevations.count,
            activeWeekCount: activeWeekCount,
            elapsedWeekCount: elapsedWeekCount,
            prHighlightTargets: prHighlightTargets,
            setsLongestRun: setsLongestRun
        )
    }

    /// Counts calendar weeks the way `activeWeekCount` does — by week *bucket*,
    /// not by elapsed days — so a runner can never be shown more active weeks
    /// than the scope contains.
    private static func calendarWeekCount(from startDate: Date?, through endDate: Date) -> Int {
        guard let startDate, startDate <= endDate else { return 1 }

        let weeksBetween = calendar.dateComponents(
            [.weekOfYear],
            from: weekStart(containing: startDate),
            to: weekStart(containing: endDate)
        ).weekOfYear ?? 0

        return max(1, weeksBetween + 1)
    }

    /// Weighted average pace by week/month for one named distance. Using the
    /// same ±5% distance bucket as Speed keeps 5K and 10K efforts separate;
    /// weighting within that bucket handles small GPS distance differences.
    static func paceTrendPoints(
        from runs: [RunWorkout],
        scope: RunTrendScope,
        unit: SpeedUnit,
        target: RunRecordTarget,
        referenceDate: Date = Date()
    ) -> [RunPaceTrendPoint] {
        let lower = scope.lowerBound(from: referenceDate, calendar: calendar)
        let scoped = runs.filter { run in
            run.startDate <= referenceDate && (lower.map { run.startDate >= $0 } ?? true)
                && run.duration > 0 && run.distanceMeters > 0
                && target.containsDistance(run.distanceMeters)
        }
        let grouped = Dictionary(grouping: scoped) { run in
            scope.bucketing == .weekly
                ? weekStart(containing: run.startDate)
                : monthStart(containing: run.startDate)
        }

        return grouped.compactMap { periodStart, periodRuns in
            let distance = totalDistance(periodRuns, unit: unit)
            let duration = periodRuns.reduce(0.0) { $0 + $1.duration }
            guard distance > 0, duration > 0 else { return nil }
            return RunPaceTrendPoint(
                id: "pace-\(Int(periodStart.timeIntervalSince1970))",
                periodStart: periodStart,
                paceMinutes: (duration / 60.0) / distance,
                runCount: periodRuns.count,
                distance: distance
            )
        }
        .sorted { $0.periodStart < $1.periodStart }
    }

    static func volumeBars(
        from runs: [RunWorkout],
        scope: RunTrendScope,
        unit: SpeedUnit,
        referenceDate: Date = Date()
    ) -> [RunVolumeBar] {
        let lower = scope.lowerBound(from: referenceDate, calendar: calendar)
        let scoped: [RunWorkout]
        if let lower {
            scoped = runs.filter { $0.startDate >= lower && $0.startDate <= referenceDate }
        } else {
            scoped = runs
        }
        guard scoped.isEmpty == false else { return [] }

        switch scope.bucketing {
        case .weekly:
            let grouped = Dictionary(grouping: scoped) { weekStart(containing: $0.startDate) }
            return grouped.map { start, weekRuns in
                let distance = totalDistance(weekRuns, unit: unit)
                let duration = weekRuns.reduce(0.0) { $0 + $1.duration }
                return RunVolumeBar(
                    id: "w-\(Int(start.timeIntervalSince1970))",
                    periodStart: start,
                    distance: distance,
                    label: RunHistoryFormatters.shortDay(start),
                    runCount: weekRuns.count,
                    averagePaceMinutes: distance > 0 ? (duration / 60.0) / distance : 0
                )
            }
            .sorted { $0.periodStart < $1.periodStart }
        case .monthly:
            let grouped = Dictionary(grouping: scoped) { monthStart(containing: $0.startDate) }
            return grouped.map { start, monthRuns in
                let distance = totalDistance(monthRuns, unit: unit)
                let duration = monthRuns.reduce(0.0) { $0 + $1.duration }
                return RunVolumeBar(
                    id: "m-\(Int(start.timeIntervalSince1970))",
                    periodStart: start,
                    distance: distance,
                    label: RunHistoryFormatters.monthShort(start),
                    runCount: monthRuns.count,
                    averagePaceMinutes: distance > 0 ? (duration / 60.0) / distance : 0
                )
            }
            .sorted { $0.periodStart < $1.periodStart }
        }
    }
}
