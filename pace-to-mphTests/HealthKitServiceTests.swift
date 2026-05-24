import Foundation
import HealthKit
import Testing
@testable import pace_to_mph

struct HealthKitServiceTests {
    @Test func mapImportableWorkoutSkipsMissingDistance() {
        let workout = makeWorkout(distanceMeters: nil, duration: 1_500)

        #expect(HealthKitService.mapImportableWorkout(workout) == nil)
    }

    @Test func mapImportableWorkoutSkipsZeroDistance() {
        let workout = makeWorkout(distanceMeters: 0, duration: 1_500)

        #expect(HealthKitService.mapImportableWorkout(workout) == nil)
    }

    @Test func mapImportableWorkoutSkipsZeroDuration() {
        let workout = makeWorkout(distanceMeters: 5_000, duration: 0)

        #expect(HealthKitService.mapImportableWorkout(workout) == nil)
    }

    @Test func mapImportableWorkoutPreservesValidRunMetrics() throws {
        let workout = makeWorkout(distanceMeters: 5_000, duration: 1_500)

        let run = try #require(HealthKitService.mapImportableWorkout(workout))
        #expect(abs(run.distanceMeters - 5_000) < 0.001)
        #expect(abs(run.duration - 1_500) < 0.001)
        #expect(run.startDate == workout.startDate)
        #expect(run.endDate == workout.endDate)
    }

    private func makeWorkout(distanceMeters: Double?, duration: TimeInterval) -> HKWorkout {
        let start = Date(timeIntervalSince1970: 1_779_552_000)
        let end = start.addingTimeInterval(duration)
        let distance = distanceMeters.map { HKQuantity(unit: .meter(), doubleValue: $0) }

        return HKWorkout(
            activityType: .running,
            start: start,
            end: end,
            duration: duration,
            totalEnergyBurned: nil,
            totalDistance: distance,
            metadata: nil
        )
    }
}
