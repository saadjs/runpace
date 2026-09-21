import Foundation
import Testing
@testable import pace_to_mph

struct RunLengthTrendTests {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func run(dayOffset: Int, miles: Double) -> RunWorkout {
        let start = base.addingTimeInterval(Double(dayOffset) * 86_400)
        let duration = miles * 9 * 60
        return RunWorkout(
            id: UUID(),
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            distanceMeters: miles * 1609.34,
            duration: duration,
            source: "Length Trend Tests",
            avgHeartRate: nil
        )
    }

    private func weekly(_ miles: [Double]) -> [RunWorkout] {
        miles.enumerated().map { run(dayOffset: $0.offset * 7, miles: $0.element) }
    }

    private func trend(_ runs: [RunWorkout], scope: RunTrendScope = .allTime, unit: SpeedUnit = .mph) -> RunLengthTrend {
        RunHistoryStats.runLengthTrend(from: runs, scope: scope, unit: unit, referenceDate: base.addingTimeInterval(400 * 86_400))
    }

    @Test func runsSteadilyGettingLongerTrendLonger() throws {
        let trend = trend(weekly([3.0, 3.6, 4.2, 4.8, 5.4, 6.0]))

        #expect(trend.direction == .longer)
        #expect(abs(trend.changeOverPeriod - 3.0) < 0.001)
        #expect(trend.changeMagnitudeText == "3.0")
        #expect(trend.averageDistanceText == "4.5")
        #expect(trend.runCount == 6)
        #expect(try #require(trend.fittedEnd) > #require(trend.fittedStart))
    }

    @Test func runsSteadilyGettingShorterTrendShorter() {
        let trend = trend(weekly([8.0, 7.2, 6.4, 5.6, 4.8, 4.0]))

        #expect(trend.direction == .shorter)
        #expect(trend.changeOverPeriod < 0)
    }

    @Test func consistentDistancesHoldSteady() {
        let trend = trend(weekly([5.0, 5.1, 4.9, 5.0, 5.05, 4.95]))

        #expect(trend.direction == .steady)
        #expect(trend.hasTrendLine)
    }

    // Four identical weeks of Sat long / Mon easy / Thu mid runs, starting on a
    // long run and ending on an easy one. The fitted line tilts down past the
    // steady band purely from where the window cuts the week.
    @Test func unchangedWeeklyRoutineIsNotCalledShorter() {
        var runs: [RunWorkout] = []
        for week in 0..<4 {
            runs.append(run(dayOffset: week * 7, miles: 9.0))
            runs.append(run(dayOffset: week * 7 + 2, miles: 3.1))
            runs.append(run(dayOffset: week * 7 + 5, miles: 6.2))
        }
        runs.removeLast()

        let trend = trend(runs)

        #expect(trend.changeOverPeriod < -0.61)
        #expect(trend.direction == .unclear)
    }

    @Test func tooFewRunsReportsInsufficientButStillFitsALine() {
        let trend = trend(weekly([3.0, 4.0, 5.0]))

        #expect(trend.direction == .insufficient)
        #expect(trend.hasTrendLine)
    }

    @Test func singleRunHasNoTrendLine() {
        let trend = trend([run(dayOffset: 0, miles: 6.2)])

        #expect(trend.direction == .insufficient)
        #expect(trend.hasTrendLine == false)
        #expect(abs(trend.averageDistance - 6.2) < 0.001)
    }

    @Test func emptyRangeHasNoData() {
        let trend = trend([])

        #expect(trend.hasData == false)
        #expect(trend.direction == .insufficient)
    }

    @Test func scopeDropsRunsOutsideTheRange() {
        let reference = base.addingTimeInterval(100 * 86_400)
        let runs = [
            run(dayOffset: 95, miles: 4.0),
            run(dayOffset: 90, miles: 5.0),
            run(dayOffset: 10, miles: 12.0)
        ]

        let trend = RunHistoryStats.runLengthTrend(from: runs, scope: .oneMonth, unit: .mph, referenceDate: reference)

        #expect(trend.runCount == 2)
        #expect(abs(trend.averageDistance - 4.5) < 0.001)
    }

    @Test func zeroDistanceRunsAreSkipped() {
        let trend = trend([run(dayOffset: 0, miles: 0), run(dayOffset: 1, miles: 3.1)])

        #expect(trend.runCount == 1)
    }

    @Test func kilometreUnitReportsKilometres() throws {
        let trend = trend([run(dayOffset: 0, miles: 5.0 / 1.60934)], unit: .kph)

        let point = try #require(trend.points.first)
        #expect(point.distanceValueText == "5.00")
        #expect(point.paceText == "5:36")
    }
}
