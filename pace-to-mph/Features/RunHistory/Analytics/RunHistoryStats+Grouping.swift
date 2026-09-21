import Foundation

extension RunHistoryStats {
    static func weeks(from runs: [RunWorkout], unit: SpeedUnit, referenceDate: Date = Date()) -> [RunHistoryWeek] {
        let currentWeekStart = weekStart(containing: referenceDate)
        let grouped = Dictionary(grouping: runs) { weekStart(containing: $0.startDate) }

        return grouped.map { startDate, weekRuns in
            let endDate = calendar.date(byAdding: .day, value: 6, to: startDate) ?? startDate
            let sortedRuns = weekRuns.sorted { $0.startDate > $1.startDate }
            let totalDistance = sortedRuns.reduce(0.0) { partial, run in
                partial + (unit == .mph ? run.distanceMiles : run.distanceKilometers)
            }
            let totalDuration = sortedRuns.reduce(0.0) { $0 + $1.duration }
            let avgSpeed = totalDuration > 0 ? totalDistance / (totalDuration / 3600.0) : 0
            let unitDistanceLabel = unit == .mph ? "mi" : "km"
            let rangeTitle = RunHistoryFormatters.weekRange(startDate, endDate)
            let title = calendar.isDate(startDate, inSameDayAs: currentWeekStart) ? "This week · \(rangeTitle)" : rangeTitle

            return RunHistoryWeek(
                id: String(Int(startDate.timeIntervalSince1970)),
                title: title,
                runCount: sortedRuns.count,
                distanceText: "\(RunHistoryFormatters.decimal(totalDistance, fractionDigits: 1)) \(unitDistanceLabel)",
                averageSpeedText: "\(RunHistoryFormatters.decimal(avgSpeed, fractionDigits: 2)) \(unit.speedLabel)",
                startDate: startDate,
                endDate: endDate,
                runs: sortedRuns,
                isCurrentWeek: calendar.isDate(startDate, inSameDayAs: currentWeekStart)
            )
        }
        .sorted { $0.startDate > $1.startDate }
    }

    /// Groups a long history by calendar month. Month starts include the year,
    /// so the all-time filter never merges (for example) January 2025 and 2026.
    static func months(from runs: [RunWorkout], unit: SpeedUnit, referenceDate: Date = Date()) -> [RunHistoryMonth] {
        let currentMonthStart = monthStart(containing: referenceDate)
        let grouped = Dictionary(grouping: runs) { monthStart(containing: $0.startDate) }

        return grouped.map { startDate, monthRuns in
            let sortedRuns = monthRuns.sorted { $0.startDate > $1.startDate }
            let totalDistance = sortedRuns.reduce(0.0) { partial, run in
                partial + (unit == .mph ? run.distanceMiles : run.distanceKilometers)
            }
            let totalDuration = sortedRuns.reduce(0.0) { $0 + $1.duration }
            let averageSpeed = totalDuration > 0 ? totalDistance / (totalDuration / 3600.0) : 0
            let distanceUnit = unit == .mph ? "mi" : "km"

            return RunHistoryMonth(
                id: String(Int(startDate.timeIntervalSince1970)),
                title: RunHistoryFormatters.monthYear(startDate),
                runCount: sortedRuns.count,
                distanceText: "\(RunHistoryFormatters.decimal(totalDistance, fractionDigits: 1)) \(distanceUnit)",
                averageSpeedText: "\(RunHistoryFormatters.decimal(averageSpeed, fractionDigits: 2)) \(unit.speedLabel)",
                startDate: startDate,
                runs: sortedRuns,
                isCurrentMonth: calendar.isDate(startDate, inSameDayAs: currentMonthStart)
            )
        }
        .sorted { $0.startDate > $1.startDate }
    }

    static func monthStart(containing date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func currentWeekInterval(containing date: Date = Date()) -> DateInterval {
        let start = weekStart(containing: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 60 * 60)
        return DateInterval(start: start, end: end)
    }

    static func currentWeekRangeText(
        containing date: Date = Date(),
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let interval = currentWeekInterval(containing: date)
        // DateInterval ends at the start of next Monday; show the final moment
        // of Sunday so the user-facing range remains inclusive.
        return RunHistoryFormatters.weekdayRange(
            interval.start,
            interval.end.addingTimeInterval(-1),
            locale: locale
        )
    }

    static func weekStart(containing date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components).map(calendar.startOfDay(for:)) ?? calendar.startOfDay(for: date)
    }
}
