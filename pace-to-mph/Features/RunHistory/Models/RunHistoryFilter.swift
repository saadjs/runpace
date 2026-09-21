import Foundation

enum RunTrendMetric: String, CaseIterable, Hashable, Identifiable {
    case speed
    case pace
    case volume
    case distance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speed: return "Speed"
        case .pace: return "Pace"
        case .volume: return "Volume"
        case .distance: return "Distance"
        }
    }

    var systemImage: String {
        switch self {
        case .speed: return RunHistorySymbols.speed
        case .pace: return RunHistorySymbols.pace
        case .volume: return "chart.bar"
        case .distance: return RunHistorySymbols.distance
        }
    }
}

enum RunHistoryMode: String, CaseIterable, Hashable, Identifiable {
    case runs
    case trends

    var id: String { rawValue }

    var title: String {
        switch self {
        case .runs: return "Runs"
        case .trends: return "Trends"
        }
    }

    var systemImage: String {
        switch self {
        case .runs: return "list.bullet"
        case .trends: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum RunHistoryPeriod: String, CaseIterable, Hashable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .week:
            return "W"
        case .month:
            return "M"
        case .year:
            return "Y"
        }
    }

    var title: String {
        switch self {
        case .week:
            return "Week"
        case .month:
            return "Month"
        case .year:
            return "Year"
        }
    }
}

enum RunHistoryYearFilter: Hashable, Identifiable {
    case allTime
    case year(Int)

    var id: String {
        switch self {
        case .allTime:
            return "allTime"
        case .year(let year):
            return "year-\(year)"
        }
    }

    var title: String {
        switch self {
        case .allTime:
            return "All Time"
        case .year(let year):
            return String(year)
        }
    }

    static func current(referenceDate: Date = Date(), calendar: Calendar = RunHistoryStats.calendar) -> RunHistoryYearFilter {
        .year(calendar.component(.year, from: referenceDate))
    }
}

enum RunHistoryFilter: Equatable {
    case currentWeek
    case month(Date)
    case year(Int)
    case allTime

    var descriptionText: String {
        switch self {
        case .currentWeek:
            return "Current Week"
        case .month(let monthStart):
            return RunHistoryFormatters.monthYear(monthStart)
        case .year(let year):
            return String(year)
        case .allTime:
            return "All Time"
        }
    }

    /// The span this filter covers, used as the denominator for run-frequency
    /// averages. `nil` for all time, which measures from the first run instead.
    func interval(calendar: Calendar, referenceDate: Date = Date()) -> DateInterval? {
        switch self {
        case .currentWeek:
            return RunHistoryStats.currentWeekInterval(containing: referenceDate)
        case .month(let monthStart):
            return calendar.dateInterval(of: .month, for: monthStart)
        case .year(let year):
            guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
                return nil
            }
            return calendar.dateInterval(of: .year, for: yearStart)
        case .allTime:
            return nil
        }
    }

    func includes(_ date: Date, calendar: Calendar, referenceDate: Date = Date()) -> Bool {
        switch self {
        case .currentWeek:
            return RunHistoryStats.currentWeekInterval(containing: referenceDate).contains(date)
        case .month(let monthStart):
            return calendar.dateInterval(of: .month, for: monthStart)?.contains(date) ?? false
        case .allTime:
            return true
        case .year(let year):
            return calendar.component(.year, from: date) == year
        }
    }
}
