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
        // Workouts without attached HR statistics degrade to no heart rate.
        // The full extraction path needs HKWorkoutBuilder (not constructible in a
        // unit test); the bpm normalization it feeds is covered separately below.
        #expect(run.avgHeartRate == nil)
    }

    @Test func normalizedHeartRateRoundsValidReadings() {
        #expect(HealthKitService.normalizedHeartRate(bpm: 152.4) == 152)
        #expect(HealthKitService.normalizedHeartRate(bpm: 152.6) == 153)
        #expect(HealthKitService.normalizedHeartRate(bpm: 150) == 150)
    }

    @Test func normalizedHeartRateRejectsMissingOrGarbageReadings() {
        #expect(HealthKitService.normalizedHeartRate(bpm: nil) == nil)
        #expect(HealthKitService.normalizedHeartRate(bpm: 0) == nil)
        #expect(HealthKitService.normalizedHeartRate(bpm: -5) == nil)
        #expect(HealthKitService.normalizedHeartRate(bpm: .nan) == nil)
        #expect(HealthKitService.normalizedHeartRate(bpm: .infinity) == nil)
    }

    @Test func normalizedElevationAcceptsFlatRunsAndRejectsGarbage() {
        #expect(HealthKitService.normalizedElevationGain(meters: 0) == 0)
        #expect(HealthKitService.normalizedElevationGain(meters: 123.4) == 123.4)
        #expect(HealthKitService.normalizedElevationGain(meters: nil) == nil)
        #expect(HealthKitService.normalizedElevationGain(meters: -1) == nil)
        #expect(HealthKitService.normalizedElevationGain(meters: .nan) == nil)
        #expect(HealthKitService.normalizedElevationGain(meters: .infinity) == nil)
    }

    @Test func mapImportableWorkoutReadsElevationMetadata() throws {
        let workout = makeWorkout(distanceMeters: 5_000, duration: 1_500, elevationMeters: 87.5)
        let run = try #require(HealthKitService.mapImportableWorkout(workout))
        #expect(run.elevationGainMeters == 87.5)
    }

    private func makeWorkout(
        distanceMeters: Double?,
        duration: TimeInterval,
        elevationMeters: Double? = nil
    ) -> HKWorkout {
        let start = Date(timeIntervalSince1970: 1_779_552_000)
        let end = start.addingTimeInterval(duration)
        let distance = distanceMeters.map { HKQuantity(unit: .meter(), doubleValue: $0) }

        let metadata = elevationMeters.map {
            [HKMetadataKeyElevationAscended: HKQuantity(unit: .meter(), doubleValue: $0)]
        }

        return HKWorkout(
            activityType: .running,
            start: start,
            end: end,
            duration: duration,
            totalEnergyBurned: nil,
            totalDistance: distance,
            metadata: metadata
        )
    }
}
