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
        #expect(summary.consistencyText == "0/13")
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
