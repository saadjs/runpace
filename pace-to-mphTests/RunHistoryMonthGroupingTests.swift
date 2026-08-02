import Foundation
import Testing
@testable import pace_to_mph

struct RunHistoryMonthGroupingTests {
    private var calendar: Calendar { RunHistoryStats.calendar }

    @Test func yearHistoryGroupsRunsByCalendarMonthNewestFirst() throws {
        let january = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 10)))
        let februaryEarly = try #require(calendar.date(from: DateComponents(year: 2026, month: 2, day: 2)))
        let februaryLate = try #require(calendar.date(from: DateComponents(year: 2026, month: 2, day: 24)))

        let months = RunHistoryStats.months(
            from: [
                run(on: january, miles: 3, minutes: 30),
                run(on: februaryEarly, miles: 4, minutes: 40),
                run(on: februaryLate, miles: 6, minutes: 60)
            ],
            unit: .mph,
            referenceDate: februaryLate
        )

        #expect(months.count == 2)
        #expect(months.map(\.runCount) == [2, 1])
        #expect(months[0].runs.map(\.startDate) == [februaryLate, februaryEarly])
        #expect(months[0].distanceText == "10.0 mi")
        #expect(months[0].averageSpeedText == "6.00 MPH")
        #expect(months[0].isCurrentMonth)
        #expect(months[1].isCurrentMonth == false)
    }

    @Test func allTimeHistoryKeepsSameNamedMonthsFromDifferentYearsSeparate() throws {
        let january2025 = try #require(calendar.date(from: DateComponents(year: 2025, month: 1, day: 10)))
        let january2026 = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 10)))

        let months = RunHistoryStats.months(
            from: [run(on: january2025), run(on: january2026)],
            unit: .mph,
            referenceDate: january2026
        )

        #expect(months.count == 2)
        #expect(months[0].id != months[1].id)
        #expect(months[0].title != months[1].title)
    }

    private func run(on date: Date, miles: Double = 3.1, minutes: Double = 30) -> RunWorkout {
        RunWorkout(
            id: UUID(),
            startDate: date,
            endDate: date.addingTimeInterval(minutes * 60),
            distanceMeters: miles * 1609.34,
            duration: minutes * 60,
            source: "Month Grouping Tests",
            avgHeartRate: nil
        )
    }
}
