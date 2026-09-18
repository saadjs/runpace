import SwiftUI

extension RunHistoryContent {
    var records: [RunPersonalRecord] {
        RunHistoryStats.personalRecords(from: runs, unit: unit)
    }

    // Always derived from the full run set so every PR badge shows in the Runs
    // list regardless of the period filter or Trends tab selection.
    var prBadgesByRunID: [UUID: [RunPRBadge]] {
        RunHistoryStats.prBadges(from: records, longestRunID: RunHistoryStats.longestRun(from: runs)?.id)
    }

    var distanceTrends: [RunDistanceTrend] {
        RunHistoryStats.speedTrendsByDistance(from: runs, scope: selectedTrendScope, unit: unit)
    }

    var availableTrendTargets: [RunRecordTarget] {
        distanceTrends.map(\.target)
    }

    // Keep the picker honest as scope/unit change buckets in and out: hold the
    // user's pick while it still has runs, otherwise fall back to their main
    // event (the distance with the most runs in scope).
    var resolvedTrendDistance: RunRecordTarget? {
        if let selectedTrendDistance, availableTrendTargets.contains(selectedTrendDistance) {
            return selectedTrendDistance
        }
        return distanceTrends.max { $0.trend.runCount < $1.trend.runCount }?.target
    }

    var overallSpeedTrend: RunSpeedTrend {
        RunHistoryStats.speedTrend(from: runs, scope: selectedTrendScope, unit: unit)
    }

    // A distance that falls out of the current scope resolves back to All Runs
    // rather than silently switching the headline to a different race distance.
    var resolvedSpeedTrendDistance: RunRecordTarget? {
        guard let selectedTrendDistance,
              availableTrendTargets.contains(selectedTrendDistance) else { return nil }
        return selectedTrendDistance
    }

    var selectedSpeedTrend: RunSpeedTrend {
        guard let resolvedSpeedTrendDistance else { return overallSpeedTrend }
        return distanceTrends.first { $0.target == resolvedSpeedTrendDistance }?.trend ?? overallSpeedTrend
    }

    var activitySummary: RunActivitySummary {
        RunHistoryStats.activitySummary(
            from: runs,
            scope: selectedTrendScope,
            unit: unit,
            records: records
        )
    }

    var volumeBars: [RunVolumeBar] {
        RunHistoryStats.volumeBars(from: runs, scope: selectedTrendScope, unit: unit)
    }

    var runLengthTrend: RunLengthTrend {
        RunHistoryStats.runLengthTrend(from: runs, scope: selectedTrendScope, unit: unit)
    }

    var paceTrendPoints: [RunPaceTrendPoint] {
        guard let target = resolvedTrendDistance else { return [] }
        return RunHistoryStats.paceTrendPoints(
            from: runs,
            scope: selectedTrendScope,
            unit: unit,
            target: target
        )
    }

    var weeks: [RunHistoryWeek] {
        RunHistoryStats.weeks(from: filteredRuns, unit: unit)
    }

    var months: [RunHistoryMonth] {
        RunHistoryStats.months(from: filteredRuns, unit: unit)
    }

    var summary: RunHistorySummary {
        RunHistoryStats.summary(from: filteredRuns, unit: unit)
    }

    var cadence: RunCadence {
        RunHistoryStats.cadence(
            from: filteredRuns,
            in: selectedFilter.interval(calendar: RunHistoryStats.calendar)
        )
    }

    var filteredRuns: [RunWorkout] {
        runs.filter { selectedFilter.includes($0.startDate, calendar: RunHistoryStats.calendar) }
    }

    var selectedFilter: RunHistoryFilter {
        switch selectedPeriod {
        case .week:
            return .currentWeek
        case .month:
            return .month(selectedMonthStart)
        case .year:
            switch selectedYearFilter {
            case .allTime:
                return .allTime
            case .year(let year):
                return .year(year)
            }
        }
    }

    var monthOptions: [Date] {
        let monthStarts = Set(runs.map { RunHistoryStats.monthStart(containing: $0.startDate) })
        return monthStarts.sorted(by: >)
    }

    var yearOptions: [RunHistoryYearFilter] {
        let years = Set(runs.map { RunHistoryStats.calendar.component(.year, from: $0.startDate) })
        return years.sorted(by: >).map(RunHistoryYearFilter.year) + [.allTime]
    }

}
