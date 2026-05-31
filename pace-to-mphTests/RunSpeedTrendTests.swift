import Foundation
import Testing
@testable import pace_to_mph

struct RunSpeedTrendTests {
    // All runs cover the same distance, so duration alone sets the speed:
    // mph = 2 miles / (duration / 3600) -> duration = 7200 / mph.
    private let twoMiles = 2 * 1609.34
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func run(weekOffset: Int, mph: Double) -> RunWorkout {
        let start = base.addingTimeInterval(Double(weekOffset) * 7 * 86_400)
        return RunWorkout(
            id: UUID(),
            startDate: start,
            endDate: start,
            distanceMeters: twoMiles,
            duration: 7_200.0 / mph,
            source: "Trend Tests"
        )
    }

    @Test func steadilyImprovingRunnerTrendsFaster() {
        let runs = [7.0, 7.2, 7.4, 7.6, 7.8, 8.0].enumerated().map { run(weekOffset: $0.offset, mph: $0.element) }
        let trend = RunHistoryStats.speedTrend(from: runs, scope: .allTime, unit: .mph)

        #expect(trend.direction == .faster)
        #expect(trend.changeOverPeriod > 0)
        #expect(trend.runCount == 6)
        #expect(trend.trendStart != nil && trend.trendEnd != nil)
    }

    @Test func steadilySlowingRunnerTrendsSlower() {
        let runs = [8.0, 7.8, 7.6, 7.4, 7.2, 7.0].enumerated().map { run(weekOffset: $0.offset, mph: $0.element) }
        let trend = RunHistoryStats.speedTrend(from: runs, scope: .allTime, unit: .mph)

        #expect(trend.direction == .slower)
        #expect(trend.changeOverPeriod < 0)
    }

    @Test func noisyButFlatRunnerHoldsSteady() {
        // Scatter well inside the steady band (~4% of a 7.5 mph average ≈ 0.3 mph).
        let runs = [7.50, 7.45, 7.55, 7.48, 7.52, 7.50].enumerated().map { run(weekOffset: $0.offset, mph: $0.element) }
        let trend = RunHistoryStats.speedTrend(from: runs, scope: .allTime, unit: .mph)

        #expect(trend.direction == .steady)
        #expect(trend.trendEnd != nil)
    }

    @Test func tooFewRunsReportsInsufficientButStillFitsALine() {
        let runs = [7.0, 7.4, 7.8].enumerated().map { run(weekOffset: $0.offset, mph: $0.element) }
        let trend = RunHistoryStats.speedTrend(from: runs, scope: .allTime, unit: .mph)

        // Line is drawn at >= 2 runs, but no faster/slower verdict below 5 runs.
        #expect(trend.direction == .insufficient)
        #expect(trend.trendEnd != nil)
        #expect(trend.runCount == 3)
    }

    @Test func singleRunHasNoTrendLine() {
        let trend = RunHistoryStats.speedTrend(from: [run(weekOffset: 0, mph: 7.5)], scope: .allTime, unit: .mph)

        #expect(trend.direction == .insufficient)
        #expect(trend.trendStart == nil)
        #expect(trend.trendEnd == nil)
        #expect(abs(trend.averageSpeed - 7.5) < 0.001)
    }

    @Test func emptyRangeHasNoData() {
        let trend = RunHistoryStats.speedTrend(from: [], scope: .allTime, unit: .mph)

        #expect(trend.hasData == false)
        #expect(trend.runCount == 0)
        #expect(trend.direction == .insufficient)
    }
}
