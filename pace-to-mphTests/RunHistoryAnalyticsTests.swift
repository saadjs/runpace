import Foundation
import Testing
@testable import pace_to_mph

struct RunHistoryAnalyticsTests {
    private let reference = Date(timeIntervalSince1970: 1_775_000_000)

    private func run(
        daysAgo: Int,
        miles: Double,
        pace: Double,
        elevationMeters: Double? = nil
    ) -> RunWorkout {
        let start = reference.addingTimeInterval(-Double(daysAgo) * 86_400)
        let duration = miles * pace * 60
        return RunWorkout(
            id: UUID(),
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            distanceMeters: miles * 1609.34,
            duration: duration,
            source: "Analytics Tests",
            avgHeartRate: nil,
            elevationGainMeters: elevationMeters
        )
    }

    @Test func recordProgressionKeepsOnlyEffortsThatBeatTheStandingRecord() {
        let runs = [
            run(daysAgo: 300, miles: 3.15, pace: 9.0),
            run(daysAgo: 200, miles: 3.15, pace: 10.0),
            run(daysAgo: 100, miles: 3.15, pace: 8.0),
            run(daysAgo: 10, miles: 6.2, pace: 8.5),
            run(daysAgo: 5, miles: 6.2, pace: 7.5)
        ]

        let progression = RunHistoryStats.recordProgression(for: .fiveKilometers, from: runs, unit: .mph)

        #expect(progression.count == 3)
        #expect(progression.map(\.paceText) == ["9:00", "8:00", "7:30"])
        #expect(progression.first?.improvementSeconds == nil)
        #expect(progression.first?.previousTimeText == nil)
    }

    @Test func recordProgressionReportsWhatEachRecordBeat() throws {
        let runs = [
            run(daysAgo: 90, miles: 3.15, pace: 9.0),
            run(daysAgo: 40, miles: 3.15, pace: 8.0)
        ]

        let progression = RunHistoryStats.recordProgression(for: .fiveKilometers, from: runs, unit: .mph)
        let current = try #require(progression.last)

        #expect(current.previousTimeText == "27:58")
        #expect(current.timeText == "24:51")
        #expect(abs((current.improvementSeconds ?? 0) - 186.4) < 0.5)
        #expect(abs((current.paceImprovementSeconds ?? 0) - 60) < 0.5)
        #expect(current.improvementText == "3:06 faster")
        #expect(current.paceImprovementText == "1:00/mi quicker")
        #expect(current.daysSincePrevious == 50)
        #expect(current.previousStoodText == "Stood for 50 days")
    }

    @Test func recordProgressionMarksEffortsExtrapolatedFromLongerRuns() {
        let runs = [
            run(daysAgo: 60, miles: 5.0 / 1.60934, pace: 9.0),
            run(daysAgo: 20, miles: 8.0, pace: 8.0)
        ]

        let progression = RunHistoryStats.recordProgression(for: .fiveKilometers, from: runs, unit: .mph)

        #expect(progression.map(\.isEstimated) == [false, true])
    }

    @Test func recordProgressionMarksSlightlyLongerGPSRunsAsEstimated() throws {
        let run = run(daysAgo: 20, miles: 5.1 / 1.60934, pace: 8.0)

        let milestone = try #require(
            RunHistoryStats.recordProgression(for: .fiveKilometers, from: [run], unit: .mph).first
        )

        #expect(milestone.isEstimated)
    }

    @Test func recordProgressionIgnoresEffortsThatOnlyMatchTheRecord() {
        let runs = [
            run(daysAgo: 60, miles: 3.15, pace: 8.0),
            run(daysAgo: 20, miles: 3.15, pace: 8.0)
        ]

        let progression = RunHistoryStats.recordProgression(for: .fiveKilometers, from: runs, unit: .mph)

        #expect(progression.count == 1)
        #expect(progression.first?.date == runs[0].startDate)
    }

    @Test func recordProgressionEndsOnTheSameRunAsThePersonalBest() throws {
        let runs = [
            run(daysAgo: 120, miles: 6.3, pace: 9.5),
            run(daysAgo: 80, miles: 6.25, pace: 8.7),
            run(daysAgo: 12, miles: 6.2, pace: 8.9)
        ]

        let record = try #require(
            RunHistoryStats.personalRecords(from: runs, unit: .mph, referenceDate: reference)
                .first { $0.target == .tenKilometers }
        )
        let progression = RunHistoryStats.recordProgression(for: .tenKilometers, from: runs, unit: .mph)

        #expect(progression.last?.id == record.runID)
        #expect(progression.count == 2)
    }

    @Test func tiedPersonalBestUsesTheSameRunInProgressionAndSummary() throws {
        let newer = run(daysAgo: 20, miles: 6.25, pace: 8.0)
        let older = run(daysAgo: 60, miles: 6.25, pace: 8.0)
        let runs = [newer, older]

        let record = try #require(
            RunHistoryStats.personalRecords(from: runs, unit: .mph, referenceDate: reference)
                .first { $0.target == .tenKilometers }
        )
        let current = try #require(
            RunHistoryStats.recordProgression(for: .tenKilometers, from: runs, unit: .mph).last
        )

        #expect(current.id == record.runID)
        #expect(current.date == record.achievedDate)
    }

    @Test func severalEffortsCanProduceOnlyOneRecordMilestone() {
        let runs = [
            run(daysAgo: 90, miles: 3.15, pace: 8.0),
            run(daysAgo: 60, miles: 3.15, pace: 8.5),
            run(daysAgo: 30, miles: 3.15, pace: 9.0)
        ]

        let progression = RunHistoryStats.recordProgression(for: .fiveKilometers, from: runs, unit: .mph)

        #expect(runs.count == 3)
        #expect(progression.count == 1)
    }

    @Test func recordProgressionIsEmptyWithoutAnyQualifyingRun() {
        let runs = [run(daysAgo: 4, miles: 2.0, pace: 8.0)]

        #expect(RunHistoryStats.recordProgression(for: .fiveKilometers, from: runs, unit: .mph).isEmpty)
    }

    @Test func comparisonUsesDistanceWeightedAveragePace() {
        let runs = [
            run(daysAgo: 10, miles: 2, pace: 8),
            run(daysAgo: 20, miles: 8, pace: 10),
            run(daysAgo: 100, miles: 10, pace: 10)
        ]

        let summary = RunHistoryStats.activitySummary(
            from: runs,
            scope: .threeMonths,
            unit: .mph,
            referenceDate: reference
        )

        #expect(abs((summary.averagePaceMinutes ?? 0) - 9.6) < 0.001)
        #expect(abs((summary.previousAveragePaceMinutes ?? 0) - 10.0) < 0.001)
        #expect(summary.averagePaceText == "9:36")
        #expect(abs((summary.paceImprovementPercent ?? 0) - 0.04) < 0.001)
    }

    @Test func highlightsIncludeLongestRunElevationConsistencyAndPRs() {
        let runs = [
            run(daysAgo: 2, miles: 3.1, pace: 8.0, elevationMeters: 40),
            run(daysAgo: 9, miles: 10, pace: 9.0, elevationMeters: 160),
            run(daysAgo: 16, miles: 6.2, pace: 8.5, elevationMeters: nil)
        ]

        let summary = RunHistoryStats.activitySummary(
            from: runs,
            scope: .threeMonths,
            unit: .mph,
            referenceDate: reference
        )

        #expect(summary.longestRunText == "10.0 mi")
        #expect(abs(summary.elevationGainMeters - 200) < 0.001)
        #expect(summary.elevationGainText == "656 ft")
        #expect(summary.activeWeekCount == 3)
        #expect(summary.consistencyText.hasPrefix("3/"))
        #expect(summary.prHighlightCount > 0)
        #expect(summary.prHighlightNames.contains("1 MILE"))
        #expect(summary.prHighlightNames.contains("5K"))
        #expect(summary.prHighlightNames.contains("10K"))
    }

    @Test func missingElevationStaysUnavailableInsteadOfShowingZero() {
        let summary = RunHistoryStats.activitySummary(
            from: [run(daysAgo: 2, miles: 3.1, pace: 9, elevationMeters: nil)],
            scope: .oneMonth,
            unit: .kph,
            referenceDate: reference
        )

        #expect(summary.hasElevationData == false)
        #expect(summary.elevationGainText == "—")
    }

    @Test func partialElevationIsLabeledInsteadOfPresentedAsComplete() {
        let summary = RunHistoryStats.activitySummary(
            from: [
                run(daysAgo: 2, miles: 3.1, pace: 9, elevationMeters: 100),
                run(daysAgo: 4, miles: 3.1, pace: 9, elevationMeters: nil)
            ],
            scope: .oneMonth,
            unit: .kph,
            referenceDate: reference
        )

        #expect(summary.elevationGainText == "100 m")
        #expect(summary.hasElevationData)
        #expect(summary.elevationGainLabel == "Partial elevation")
    }

    @Test func consistencyCountsTheCalendarWeeksIntersectingTheScope() throws {
        let calendar = RunHistoryStats.calendar
        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 12))
        )
        let runs = [31, 24, 17, 10, 3, 0].map { daysAgo in
            let start = calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate) ?? referenceDate
            return RunWorkout(
                id: UUID(),
                startDate: start,
                endDate: start.addingTimeInterval(30 * 60),
                distanceMeters: 5_000,
                duration: 30 * 60,
                source: "Analytics Tests",
                avgHeartRate: nil
            )
        }

        let summary = RunHistoryStats.activitySummary(
            from: runs,
            scope: .oneMonth,
            unit: .kph,
            referenceDate: referenceDate
        )

        #expect(summary.activeWeekCount == 6)
        #expect(summary.consistencyText == "6/6")
    }

    @Test func paceTrendUsesWeeklyWeightedBucketsForShortScopes() throws {
        let points = RunHistoryStats.paceTrendPoints(
            from: [
                run(daysAgo: 1, miles: 3.1, pace: 8),
                run(daysAgo: 1, miles: 3.1, pace: 10),
                run(daysAgo: 1, miles: 6.2, pace: 12),
                run(daysAgo: 9, miles: 3.1, pace: 11)
            ],
            scope: .threeMonths,
            unit: .mph,
            target: .fiveKilometers,
            referenceDate: reference
        )

        #expect(points.count == 2)
        let latest = try #require(points.last)
        #expect(abs(latest.paceMinutes - 9.0) < 0.001)
        #expect(latest.runCount == 2)
        #expect(abs(latest.distance - 6.2) < 0.001)
        #expect(latest.paceText == "9:00")
    }

    @Test func volumeBarsCarryInspectableRunCountAndWeightedPace() throws {
        let bars = RunHistoryStats.volumeBars(
            from: [
                run(daysAgo: 1, miles: 2, pace: 8),
                run(daysAgo: 1, miles: 8, pace: 10)
            ],
            scope: .threeMonths,
            unit: .mph,
            referenceDate: reference
        )

        let bar = try #require(bars.first)
        #expect(bars.count == 1)
        #expect(bar.runCount == 2)
        #expect(abs(bar.distance - 10) < 0.001)
        #expect(abs(bar.averagePaceMinutes - 9.6) < 0.001)
        #expect(bar.paceText == "9:36")
    }

    @Test func paceTrendUsesMonthlyBucketsForYearScope() {
        let points = RunHistoryStats.paceTrendPoints(
            from: [
                run(daysAgo: 5, miles: 3, pace: 8.5),
                run(daysAgo: 40, miles: 3, pace: 9.0),
                run(daysAgo: 400, miles: 3, pace: 12.0)
            ],
            scope: .oneYear,
            unit: .mph,
            target: .fiveKilometers,
            referenceDate: reference
        )

        #expect(points.count == 2)
        #expect(points.allSatisfy { $0.paceMinutes < 10 })
    }

    @Test func emptyAnalyticsAreStable() {
        let summary = RunHistoryStats.activitySummary(
            from: [],
            scope: .threeMonths,
            unit: .mph,
            referenceDate: reference
        )

        #expect(summary.runCount == 0)
        #expect(summary.averagePaceText == "—")
        #expect(summary.longestRunText == "0.0 mi")
        #expect(summary.consistencyText == "0/14")
        #expect(summary.prHighlightCount == 0)
        #expect(RunHistoryStats.paceTrendPoints(
            from: [],
            scope: .allTime,
            unit: .mph,
            target: .fiveKilometers,
            referenceDate: reference
        ).isEmpty)
    }
}
