import Testing
@testable import pace_to_mph

struct RaceCalculatorTests {

    // MARK: - Finish Time

    @Test func finishTimeBasic() {
        // 8:00/mi pace for 3.10686 miles (5K) ≈ 24:51
        let seconds = RaceCalculator.finishTime(paceMinutes: 8.0, distanceInUnits: 3.10686)
        #expect(seconds == 1491) // 24*60 + 51 = 1491
    }

    // MARK: - Format Duration

    @Test func formatDurationUnderHour() {
        #expect(RaceCalculator.formatDuration(1491) == "24:51")
    }

    @Test func formatDurationOverHour() {
        #expect(RaceCalculator.formatDuration(3661) == "1:01:01")
    }

    @Test func formatDurationZero() {
        #expect(RaceCalculator.formatDuration(0) == "0:00")
    }

    // MARK: - Required Pace

    @Test func requiredPaceBasic() {
        // 24:51 (1491s) over 3.10686mi = ~8.0 min/mi
        let pace = RaceCalculator.requiredPace(totalSeconds: 1491, distanceInUnits: 3.10686)
        #expect(abs(pace - 8.0) < 0.01)
    }

    // MARK: - Parse Duration

    @Test func parseDurationHMS() {
        #expect(RaceCalculator.parseDuration("1:30:00") == 5400)
    }

    @Test func parseDurationMS() {
        #expect(RaceCalculator.parseDuration("24:51") == 1491)
    }

    @Test func parseDurationMinutesOnly() {
        #expect(RaceCalculator.parseDuration("30") == 1800)
    }

    @Test func parseDurationInvalid() {
        #expect(RaceCalculator.parseDuration("") == nil)
        #expect(RaceCalculator.parseDuration("abc") == nil)
        #expect(RaceCalculator.parseDuration("1:2:3:4") == nil)
    }

    // MARK: - Negative Splits

    @Test func negativeSplitsEvenDistance() {
        // 30:00 over 3 miles, 5s drop per split
        let splits = RaceCalculator.negativeSplits(totalSeconds: 1800, distanceInUnits: 3.0, dropSeconds: 5.0)
        #expect(splits.count == 3)
        // Total should sum to 1800
        let total = splits.reduce(0) { $0 + $1.seconds }
        #expect(abs(total - 1800) <= 1) // allow 1s rounding
        // Each split should be faster than previous
        #expect(splits[1].seconds < splits[0].seconds)
        #expect(splits[2].seconds < splits[1].seconds)
    }

    @Test func negativeSplitsWithPartial() {
        // 25:00 over 3.1 miles
        let splits = RaceCalculator.negativeSplits(totalSeconds: 1500, distanceInUnits: 3.1, dropSeconds: 3.0)
        #expect(splits.count == 4) // 3 full + 1 partial
        #expect(splits.last!.distance < 1.0) // partial
        #expect(abs(splits.last!.distance - 0.1) < 0.01)
    }

    @Test func negativeSplitsZeroDrop() {
        // Even splits when drop is 0
        let splits = RaceCalculator.negativeSplits(totalSeconds: 1800, distanceInUnits: 3.0, dropSeconds: 0.0)
        #expect(splits.count == 3)
        #expect(splits[0].seconds == splits[1].seconds)
        #expect(splits[1].seconds == splits[2].seconds)
    }

    @Test func negativeSplitsInvalidInput() {
        #expect(RaceCalculator.negativeSplits(totalSeconds: 0, distanceInUnits: 3.0, dropSeconds: 5.0).isEmpty)
        #expect(RaceCalculator.negativeSplits(totalSeconds: 1800, distanceInUnits: 0, dropSeconds: 5.0).isEmpty)
    }

    @Test func negativeSplitsLargeDropPreservesRequestedTotal() {
        let splits = RaceCalculator.negativeSplits(totalSeconds: 60, distanceInUnits: 2.0, dropSeconds: 59)
        #expect(splits.count == 2)
        #expect(splits.reduce(0) { $0 + $1.seconds } == 60)
        #expect(splits.allSatisfy { $0.seconds > 0 })
    }

    // Regression: when rounding produces difference > 0, adding to the last (fastest)
    // split can make it equal to or slower than the prior split (202s/6mi/1s drop → diff=1
    // adds to last, making splits[5]==splits[4]==32). Should add to first split instead.
    @Test func negativeSplitsRoundingPreservesStrictlyDecreasingOrder() {
        let splits = RaceCalculator.negativeSplits(totalSeconds: 202, distanceInUnits: 6.0, dropSeconds: 1.0)
        #expect(splits.count == 6)
        #expect(splits.reduce(0) { $0 + $1.seconds } == 202)
        for i in 1..<splits.count {
            #expect(splits[i].seconds < splits[i - 1].seconds,
                    "split \(i) (\(splits[i].seconds)s) must be faster than split \(i-1) (\(splits[i-1].seconds)s)")
        }
    }

    // Regression: when rounding produces difference < 0 (total overshoots), correcting
    // the first split gives [1,1] — equal, not strictly decreasing. Since this is purely
    // a rounding artifact (ideal split times are 1.5s and 0.5s), equal adjacent splits
    // are acceptable. The result must be non-increasing and sum to totalSeconds.
    @Test func negativeSplitsNegativeDiffPreservesNonIncreasingOrder() {
        let splits = RaceCalculator.negativeSplits(totalSeconds: 2, distanceInUnits: 2.0, dropSeconds: 1.0)
        // Either returns valid non-increasing splits or empty (drop is truly impossible to satisfy)
        if !splits.isEmpty {
            #expect(splits.reduce(0) { $0 + $1.seconds } == 2)
            for i in 1..<splits.count {
                #expect(splits[i].seconds <= splits[i - 1].seconds,
                        "split \(i) (\(splits[i].seconds)s) must be <= split \(i-1) (\(splits[i-1].seconds)s)")
            }
        }
    }

    // Regression: when difference < 0 corrects the first split and leaves it equal to
    // the second, the result was incorrectly discarded. Equal adjacent splits caused by
    // integer rounding are acceptable and should be returned.
    // 5s/3mi/1s drop → basePace=2.667, rounds to [3,2,1]=6, diff=-1 → [2,2,1]=5.
    // The first two splits are equal: a rounding artifact, not an impossible case.
    @Test func negativeSplitsNegativeDiffAllowsEqualAdjacentFromRounding() {
        let splits = RaceCalculator.negativeSplits(totalSeconds: 5, distanceInUnits: 3.0, dropSeconds: 1.0)
        #expect(splits.count == 3)
        #expect(splits.reduce(0) { $0 + $1.seconds } == 5)
        for i in 1..<splits.count {
            #expect(splits[i].seconds <= splits[i - 1].seconds,
                    "split \(i) (\(splits[i].seconds)s) must be <= split \(i-1) (\(splits[i-1].seconds)s)")
        }
    }

    // Regression: when rounded splits overshoot the requested total, removing all excess
    // from the first split can make it faster than the next split and incorrectly return
    // no result. The correction should be spread across the earlier splits instead.
    @Test func negativeSplitsDistributesOvershootAcrossEarlierSplits() {
        let splits = RaceCalculator.negativeSplits(totalSeconds: 900, distanceInUnits: 3.10686, dropSeconds: 0.0)
        #expect(splits.count == 4)
        #expect(splits.reduce(0) { $0 + $1.seconds } == 900)
        for i in 1..<splits.count {
            #expect(splits[i].seconds <= splits[i - 1].seconds,
                    "split \(i) (\(splits[i].seconds)s) must be <= split \(i-1) (\(splits[i-1].seconds)s)")
        }
    }
}
