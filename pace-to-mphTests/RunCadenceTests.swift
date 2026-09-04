import Foundation
import Testing
@testable import pace_to_mph

/// Covers the run-frequency averages shown under the totals on the Runs and
/// Trends tabs: how many runs per week / per month over a given window.
struct RunCadenceTests {
    private let calendar = RunHistoryStats.calendar
    private let reference = Date(timeIntervalSince1970: 1_772_000_000)  // 2026-02-25

    private func run(daysAgo: Int, miles: Double = 3.1, minutes: Double = 26) -> RunWorkout {
        let start = reference.addingTimeInterval(-Double(daysAgo) * 86_400)
        return RunWorkout(
            id: UUID(),
            startDate: start,
            endDate: start.addingTimeInterval(minutes * 60),
            distanceMeters: miles * 1609.34,
            duration: minutes * 60,
            source: "Cadence Tests",
            avgHeartRate: nil
        )
    }

    // MARK: - Averages

    @Test func averagesRunsAcrossTheWindowLength() {
        // 24 runs over an 8-week window -> 3 a week.
        let runs = (0..<24).map { run(daysAgo: $0 * 2 + 1) }
        let start = reference.addingTimeInterval(-56 * 86_400)
        let cadence = RunHistoryStats.cadence(
            from: runs,
            in: DateInterval(start: start, end: reference),
            referenceDate: reference
        )

        #expect(cadence.runCount == 24)
        #expect(abs(cadence.runsPerWeek - 3.0) < 0.01)
        #expect(abs(cadence.weeks - 8.0) < 0.01)
        #expect(cadence.runsPerWeekText == "3.0")
    }

    @Test func perMonthAverageUsesCalendarMonthLength() {
        // 60 runs over a year -> 5 a month, ~1.15 a week.
        let runs = (0..<60).map { run(daysAgo: $0 * 6 + 1) }
        let start = calendar.date(byAdding: .year, value: -1, to: reference)!
        let cadence = RunHistoryStats.cadence(
            from: runs,
            in: DateInterval(start: start, end: reference),
            referenceDate: reference
        )

        #expect(abs(cadence.runsPerMonth - 5.0) < 0.05)
        #expect(cadence.runsPerMonthText == "5.0")
        #expect(cadence.hasMonthlyAverage)
    }

    // MARK: - Window handling

    @Test func windowIsClippedToNowSoTheUnfinishedMonthDoesNotDilute() {
        // A full-month window with only the first week elapsed must average over
        // that week, not over the whole month.
        let monthInterval = calendar.dateInterval(of: .month, for: reference)!
        let oneWeekIn = calendar.date(byAdding: .day, value: 7, to: monthInterval.start)!
        let runs = [run(daysAgo: 0), run(daysAgo: 1), run(daysAgo: 3)]

        let cadence = RunHistoryStats.cadence(from: runs, in: monthInterval, referenceDate: oneWeekIn)

        #expect(abs(cadence.weeks - 1.0) < 0.01)
        #expect(cadence.months == 1)
    }

    @Test func allTimeMeasuresFromTheFirstRun() {
        let runs = [run(daysAgo: 70), run(daysAgo: 35), run(daysAgo: 7)]
        let cadence = RunHistoryStats.cadence(from: runs, in: nil, referenceDate: reference)

        #expect(abs(cadence.weeks - 10.0) < 0.01)
        #expect(abs(cadence.runsPerWeek - 0.3) < 0.01)
    }

    @Test func currentWeekRangeNamesItsMondayThroughSundayWindow() {
        let friday = calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 4, hour: 12)
        )!

        #expect(
            RunHistoryStats.currentWeekRangeText(
                containing: friday,
                locale: Locale(identifier: "en_US")
            )
                == "Mon, Aug 31 – Sun, Sep 6, 2026"
        )
    }

    @Test func trendScopesExposeTheirActualRollingDates() {
        let septemberFourth = calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 4, hour: 12)
        )!
        let firstRun = calendar.date(
            from: DateComponents(year: 2025, month: 12, day: 20, hour: 12)
        )!

        #expect(
            RunTrendScope.threeMonths.dateRangeText(
                referenceDate: septemberFourth,
                earliestRunDate: firstRun,
                calendar: calendar,
                locale: Locale(identifier: "en_US")
            ) == "Jun 4 – Sep 4, 2026"
        )
        #expect(
            RunTrendScope.allTime.dateRangeText(
                referenceDate: septemberFourth,
                earliestRunDate: firstRun,
                calendar: calendar,
                locale: Locale(identifier: "en_US")
            ) == "Dec 20, 2025 – Sep 4, 2026"
        )
    }

    @Test func shortWindowIsFlooredAtOneWeekAndOneMonth() {
        // 3 runs in 3 days is not 7 runs a week.
        let start = reference.addingTimeInterval(-3 * 86_400)
        let runs = [run(daysAgo: 0), run(daysAgo: 1), run(daysAgo: 2)]
        let cadence = RunHistoryStats.cadence(
            from: runs,
            in: DateInterval(start: start, end: reference),
            referenceDate: reference
        )

        #expect(cadence.weeks == 1)
        #expect(cadence.months == 1)
        #expect(cadence.runsPerWeek == 3)
    }

    // MARK: - Presentation gating

    @Test func singleWeekWindowOffersNoAverages() {
        // Averaging over one week just restates the total, so nothing is shown.
        let week = RunHistoryStats.currentWeekInterval(containing: reference)
        let cadence = RunHistoryStats.cadence(from: [run(daysAgo: 0), run(daysAgo: 1)], in: week, referenceDate: reference)

        #expect(cadence.hasWeeklyAverage == false)
        #expect(cadence.hasMonthlyAverage == false)
        #expect(cadence.averageText == nil)
    }

    @Test func monthWindowOffersWeeklyButNotMonthlyAverage() {
        let monthInterval = calendar.dateInterval(of: .month, for: reference)!
        let runs = (0..<12).map { run(daysAgo: $0 * 2) }
        let cadence = RunHistoryStats.cadence(from: runs, in: monthInterval, referenceDate: reference)

        #expect(cadence.hasWeeklyAverage)
        #expect(cadence.hasMonthlyAverage == false)
        #expect(cadence.averageText?.contains("runs/wk") == true)
        #expect(cadence.averageText?.contains("runs/mo") == false)
    }

    @Test func yearWindowOffersBothAverages() {
        let start = calendar.date(byAdding: .year, value: -1, to: reference)!
        let runs = (0..<52).map { run(daysAgo: $0 * 7) }
        let cadence = RunHistoryStats.cadence(
            from: runs,
            in: DateInterval(start: start, end: reference),
            referenceDate: reference
        )

        #expect(cadence.hasWeeklyAverage)
        #expect(cadence.hasMonthlyAverage)
        #expect(cadence.averageText?.contains("runs/wk") == true)
        #expect(cadence.averageText?.contains("runs/mo") == true)
    }

    @Test func emptyWindowHasNoAverages() {
        let start = calendar.date(byAdding: .month, value: -6, to: reference)!
        let cadence = RunHistoryStats.cadence(
            from: [],
            in: DateInterval(start: start, end: reference),
            referenceDate: reference
        )

        #expect(cadence.runCount == 0)
        #expect(cadence.runsPerWeek == 0)
        #expect(cadence.averageText == nil)
    }

    // MARK: - Trends tab wiring

    @Test func activitySummaryCarriesCadenceForItsScope() {
        // 3 runs a week for 6 months, read through the 3-month scope.
        let runs = (0..<78).map { run(daysAgo: Int(Double($0) * 2.33)) }
        let summary = RunHistoryStats.activitySummary(
            from: runs,
            scope: .threeMonths,
            unit: .mph,
            referenceDate: reference
        )

        #expect(summary.cadence.runCount == summary.runCount)
        #expect(summary.cadence.hasWeeklyAverage)
        #expect(summary.cadence.hasMonthlyAverage)
        #expect(summary.cadence.runsPerWeek > 2.5 && summary.cadence.runsPerWeek < 3.5)
    }

    /// The Weekly Volume card divides by the scope's elapsed weeks, not by the
    /// number of bars, so weeks the runner sat out still count against the
    /// average and the figure matches the Activity card on the same screen.
    @Test func cadenceCountsSilentWeeksAgainstTheAverage() {
        // Two runs in one week, nothing for the rest of the three-month scope.
        let runs = [run(daysAgo: 36), run(daysAgo: 35)]
        let summary = RunHistoryStats.activitySummary(
            from: runs,
            scope: .threeMonths,
            unit: .mph,
            referenceDate: reference
        )
        let bars = RunHistoryStats.volumeBars(
            from: runs,
            scope: .threeMonths,
            unit: .mph,
            referenceDate: reference
        )

        #expect(bars.count <= 2)
        #expect(summary.cadence.weeks > 12)
        #expect(summary.cadence.runsPerWeek < 0.2)
    }
}
