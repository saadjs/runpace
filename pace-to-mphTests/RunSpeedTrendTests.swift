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
            source: "Trend Tests",
            avgHeartRate: nil
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

    // MARK: - Per-distance bucketing

    private func run(distanceMeters: Double, dayOffset: Int = 0) -> RunWorkout {
        let start = base.addingTimeInterval(Double(dayOffset) * 86_400)
        // Hold a constant ~7 mph so duration stays valid for any distance.
        let hours = (distanceMeters / 1609.34) / 7.0
        return RunWorkout(
            id: UUID(),
            startDate: start,
            endDate: start.addingTimeInterval(hours * 3_600),
            distanceMeters: distanceMeters,
            duration: hours * 3_600,
            source: "Bucket Tests",
            avgHeartRate: nil
        )
    }

    @Test func bucketsRunsByNamedDistanceAndExcludesGapDistances() {
        let runs = [
            run(distanceMeters: 5_000, dayOffset: 0),
            run(distanceMeters: 5_050, dayOffset: 1),
            run(distanceMeters: 10_000, dayOffset: 2),
            run(distanceMeters: 9_800, dayOffset: 3),
            run(distanceMeters: 3_218, dayOffset: 4) // ~2 miles: between 1mi and 5K bands
        ]

        let trends = RunHistoryStats.speedTrendsByDistance(from: runs, scope: .allTime, unit: .mph)

        #expect(trends.map(\.target) == [.fiveKilometers, .tenKilometers])
        #expect(trends.first { $0.target == .fiveKilometers }?.trend.runCount == 2)
        #expect(trends.first { $0.target == .tenKilometers }?.trend.runCount == 2)
    }

    @Test func toleranceBandIsInclusiveAtTenPercent() {
        let runs = [
            run(distanceMeters: 4_500, dayOffset: 0), // exactly -10% of 5K
            run(distanceMeters: 5_500, dayOffset: 1), // exactly +10% of 5K
            run(distanceMeters: 4_499, dayOffset: 2), // just outside the band
            run(distanceMeters: 5_501, dayOffset: 3)  // just outside the band
        ]

        let trends = RunHistoryStats.speedTrendsByDistance(from: runs, scope: .allTime, unit: .mph)

        #expect(trends.map(\.target) == [.fiveKilometers])
        #expect(trends.first?.trend.runCount == 2)
    }

    @Test func distanceNeedsAtLeastTwoRunsToAppear() {
        let runs = [
            run(distanceMeters: 5_000, dayOffset: 0), // lone 5K
            run(distanceMeters: 10_000, dayOffset: 1),
            run(distanceMeters: 10_100, dayOffset: 2)
        ]

        let trends = RunHistoryStats.speedTrendsByDistance(from: runs, scope: .allTime, unit: .mph)

        #expect(trends.map(\.target) == [.tenKilometers])
    }

    @Test func bucketsRespectUnitVisibility() {
        let runs = [
            run(distanceMeters: 1_609, dayOffset: 0), // 1 mile
            run(distanceMeters: 1_620, dayOffset: 1),
            run(distanceMeters: 1_000, dayOffset: 2), // 1 km
            run(distanceMeters: 990, dayOffset: 3)
        ]

        let mph = RunHistoryStats.speedTrendsByDistance(from: runs, scope: .allTime, unit: .mph).map(\.target)
        let kph = RunHistoryStats.speedTrendsByDistance(from: runs, scope: .allTime, unit: .kph).map(\.target)

        #expect(mph.contains(.oneMile))
        #expect(!mph.contains(.oneKilometer))
        #expect(kph.contains(.oneKilometer))
        #expect(!kph.contains(.oneMile))
    }

    @Test func trendsAreOrderedByAscendingDistance() {
        let runs = [
            run(distanceMeters: 42_195, dayOffset: 0),
            run(distanceMeters: 42_000, dayOffset: 1),
            run(distanceMeters: 5_000, dayOffset: 2),
            run(distanceMeters: 5_010, dayOffset: 3),
            run(distanceMeters: 10_000, dayOffset: 4),
            run(distanceMeters: 9_900, dayOffset: 5)
        ]

        let trends = RunHistoryStats.speedTrendsByDistance(from: runs, scope: .allTime, unit: .mph)

        #expect(trends.map(\.target) == [.fiveKilometers, .tenKilometers, .marathon])
    }
}
