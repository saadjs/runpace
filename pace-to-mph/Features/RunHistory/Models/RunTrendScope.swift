import Foundation

enum RunTrendScope: String, CaseIterable, Hashable, Identifiable {
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case allTime

    var id: String { rawValue }

    var menuLabel: String {
        switch self {
        case .oneMonth: return "Last month"
        case .threeMonths: return "Last 3 months"
        case .sixMonths: return "Last 6 months"
        case .oneYear: return "Last year"
        case .allTime: return "All time"
        }
    }

    var bucketing: RunVolumeBucketing {
        switch self {
        case .oneMonth, .threeMonths, .sixMonths: return .weekly
        case .oneYear, .allTime: return .monthly
        }
    }

    func lowerBound(from date: Date, calendar: Calendar) -> Date? {
        switch self {
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: date)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: date)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: date)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: date)
        case .allTime:
            return nil
        }
    }

    func previousLowerBound(from date: Date, calendar: Calendar) -> Date? {
        switch self {
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -2, to: date)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -6, to: date)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -12, to: date)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -2, to: date)
        case .allTime:
            return nil
        }
    }

    func dateRangeText(
        referenceDate: Date = Date(),
        earliestRunDate: Date?,
        calendar: Calendar = RunHistoryStats.calendar,
        locale: Locale = .autoupdatingCurrent
    ) -> String? {
        let start = lowerBound(from: referenceDate, calendar: calendar) ?? earliestRunDate
        guard let start else { return nil }
        return RunHistoryFormatters.dateRange(start, referenceDate, locale: locale)
    }
}

enum RunVolumeBucketing {
    case weekly
    case monthly
}
