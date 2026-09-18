import Foundation
import Testing
@testable import pace_to_mph

struct RunLongestRunTests {
    private let reference = Date(timeIntervalSince1970: 1_775_000_000)

    private func run(daysAgo: Int, miles: Double, pace: Double = 9.0) -> RunWorkout {
        let start = reference.addingTimeInterval(-Double(daysAgo) * 86_400)
        let duration = miles * pace * 60
        return RunWorkout(
            id: UUID(),
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            distanceMeters: miles * 1609.34,
            duration: duration,
            source: "Longest Run Tests",
            avgHeartRate: nil
        )
    }

    @Test func progressionKeepsOnlyRunsThatWentFarther() {
        let runs = [
            run(daysAgo: 100, miles: 3),
            run(daysAgo: 90, miles: 5),
            run(daysAgo: 80, miles: 4),
            run(daysAgo: 70, miles: 8),
            run(daysAgo: 60, miles: 6),
            run(daysAgo: 50, miles: 10)
        ]

        let progression = RunHistoryStats.longestRunProgression(from: runs, unit: .mph)

        #expect(progression.map(\.distanceValueText) == ["3.00", "5.00", "8.00", "10.00"])
        #expect(progression.first?.extraDistance == nil)
        #expect(progression.first?.extraDistanceText == nil)
    }

    @Test func progressionReportsWhatEachRecordBeat() throws {
        let runs = [
            run(daysAgo: 60, miles: 8, pace: 9),
            run(daysAgo: 30, miles: 10, pace: 9)
        ]

        let current = try #require(RunHistoryStats.longestRunProgression(from: runs, unit: .mph).last)

        #expect(current.distanceText == "10.00 mi")
        #expect(current.previousDistanceText == "8.00 mi")
        #expect(current.extraDistanceText == "2.00 mi farther")
        #expect(current.timeText == "1:30:00")
        #expect(current.paceText == "9:00")
        #expect(current.previousStoodText == "Stood for 30 days")
    }

    @Test func tiedLongestRunKeepsTheEarlierRun() throws {
        let earlier = run(daysAgo: 60, miles: 13.1)
        let later = run(daysAgo: 20, miles: 13.1)

        let longest = try #require(RunHistoryStats.longestRun(from: [later, earlier]))
        let progression = RunHistoryStats.longestRunProgression(from: [later, earlier], unit: .mph)

        #expect(longest.id == earlier.id)
        #expect(progression.count == 1)
        #expect(progression.last?.id == earlier.id)
    }

    @Test func longestRunIgnoresZeroDistanceRuns() {
        let empty = RunWorkout(
            id: UUID(),
            startDate: reference,
            endDate: reference,
            distanceMeters: 0,
            duration: 600,
            source: "Longest Run Tests",
            avgHeartRate: nil
        )

        #expect(RunHistoryStats.longestRun(from: [empty]) == nil)
        #expect(RunHistoryStats.longestRunProgression(from: [empty], unit: .mph).isEmpty)
        #expect(RunHistoryStats.longestRun(from: []) == nil)
    }

    @Test func kilometreUnitReportsKilometres() throws {
        let milestone = try #require(
            RunHistoryStats.longestRunProgression(from: [run(daysAgo: 5, miles: 10 / 1.60934)], unit: .kph).last
        )

        #expect(milestone.distanceText == "10.00 km")
    }

    @Test func prBadgesAddLongestRunAfterDistanceRecords() throws {
        let fastShort = RunWorkout(
            id: UUID(),
            startDate: reference,
            endDate: reference.addingTimeInterval(1_200),
            distanceMeters: 5_000,
            duration: 1_200,
            source: "Longest Run Tests",
            avgHeartRate: nil
        )
        let slowLong = RunWorkout(
            id: UUID(),
            startDate: reference,
            endDate: reference.addingTimeInterval(14_400),
            distanceMeters: 42_195,
            duration: 14_400,
            source: "Longest Run Tests",
            avgHeartRate: nil
        )
        let runs = [fastShort, slowLong]
        let records = RunHistoryStats.personalRecords(from: runs, unit: .mph, referenceDate: reference)

        let badges = RunHistoryStats.prBadges(
            from: records,
            longestRunID: RunHistoryStats.longestRun(from: runs)?.id
        )

        #expect(badges[fastShort.id] == [.record(.oneMile), .record(.fiveKilometers)])
        #expect(badges[slowLong.id] == [
            .record(.tenKilometers),
            .record(.halfMarathon),
            .record(.marathon),
            .longestRun
        ])
        #expect(badges[slowLong.id]?.last?.title == "LONGEST")
    }

    @Test func longestRunBadgeAppearsOnRunsWithoutOtherRecords() {
        let short = run(daysAgo: 3, miles: 0.5)

        let badges = RunHistoryStats.prBadges(from: [], longestRunID: short.id)

        #expect(badges[short.id] == [.longestRun])
    }

    @Test func periodHighlightsCountTheLongestRunOnlyWhenItFallsInScope() {
        let runs = [
            run(daysAgo: 5, miles: 3.1),
            run(daysAgo: 200, miles: 13.1)
        ]

        let recent = RunHistoryStats.activitySummary(from: runs, scope: .threeMonths, unit: .mph, referenceDate: reference)
        let allTime = RunHistoryStats.activitySummary(from: runs, scope: .allTime, unit: .mph, referenceDate: reference)

        #expect(recent.setsLongestRun == false)
        #expect(recent.prHighlightNames.contains("LONGEST") == false)
        #expect(allTime.setsLongestRun)
        #expect(allTime.prHighlightCount == allTime.prHighlightTargets.count + 1)
        #expect(allTime.prHighlightNames.hasSuffix("LONGEST"))
        #expect(allTime.prHighlightAccessibilityNames.hasSuffix("Longest run"))
    }
}
