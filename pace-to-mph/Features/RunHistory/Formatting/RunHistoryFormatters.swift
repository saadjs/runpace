import Foundation

nonisolated enum RunHistoryFormatters {
    static func decimal(_ value: Double, fractionDigits: Int) -> String {
        String(format: "%.\(fractionDigits)f", value)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    static func distance(meters: Double, unit: SpeedUnit) -> Double {
        unit == .mph ? meters / 1609.34 : meters / 1000.0
    }

    static func stood(days: Int) -> String? {
        guard days > 0 else { return nil }
        if days < 60 {
            return "Stood for \(days) days"
        }
        let months = Int((Double(days) / 30.436_875).rounded())
        if months < 24 {
            return "Stood for \(months) months"
        }
        return "Stood for \(months / 12) years"
    }

    static func gap(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded())
        if seconds < 60 { return "\(seconds)s" }
        return duration(TimeInterval(seconds))
    }

    static func weekRange(_ startDate: Date, _ endDate: Date) -> String {
        let startMonth = monthFormatter.string(from: startDate)
        let endMonth = monthFormatter.string(from: endDate)
        let startDay = dayFormatter.string(from: startDate)
        let endDay = dayFormatter.string(from: endDate)

        if startMonth == endMonth {
            return "\(startMonth) \(startDay)–\(endDay)"
        }
        return "\(startMonth) \(startDay) – \(endMonth) \(endDay)"
    }

    static func weekdayRange(
        _ startDate: Date,
        _ endDate: Date,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let weekdayDateFormatter = formatter(locale: locale, template: "EEE MMMd")
        let yearFormatter = formatter(locale: locale, template: "yyyy")
        let start = weekdayDateFormatter.string(from: startDate)
        let end = weekdayDateFormatter.string(from: endDate)

        if Calendar.autoupdatingCurrent.component(.year, from: startDate)
            == Calendar.autoupdatingCurrent.component(.year, from: endDate) {
            return "\(start) – \(end), \(yearFormatter.string(from: endDate))"
        }
        return "\(start), \(yearFormatter.string(from: startDate)) – \(end), \(yearFormatter.string(from: endDate))"
    }

    static func dateRange(
        _ startDate: Date,
        _ endDate: Date,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let shortDayFormatter = formatter(locale: locale, template: "MMMd")
        let yearFormatter = formatter(locale: locale, template: "yyyy")
        let start = shortDayFormatter.string(from: startDate)
        let end = shortDayFormatter.string(from: endDate)

        if Calendar.autoupdatingCurrent.component(.year, from: startDate)
            == Calendar.autoupdatingCurrent.component(.year, from: endDate) {
            return "\(start) – \(end), \(yearFormatter.string(from: endDate))"
        }
        return "\(start), \(yearFormatter.string(from: startDate)) – \(end), \(yearFormatter.string(from: endDate))"
    }

    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    static func monthShort(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }

    static func shortDay(_ date: Date) -> String {
        shortDayFormatter.string(from: date)
    }

    static func longDate(_ date: Date) -> String {
        longDateFormatter.string(from: date)
    }

    static func percent(_ value: Double) -> String {
        let percent = value * 100
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.0f", abs(percent)))%"
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("d")
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        return formatter
    }()

    private static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    private static func formatter(locale: Locale, template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        return formatter
    }()
}

extension SpeedUnit {
    var distanceLabel: String { self == .mph ? "mi" : "km" }
}
