import Foundation
import HealthKit

extension HealthKitService {
    nonisolated static func mapImportableWorkout(_ workout: HKWorkout) -> RunWorkout? {
        let meters: Double = {
            if let stats = workout.statistics(for: HKQuantityType(.distanceWalkingRunning)),
               let sum = stats.sumQuantity() {
                return sum.doubleValue(for: .meter())
            }
            // Fallback for older samples.
            return workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        }()

        guard meters.isFinite, meters > 0,
              workout.duration.isFinite, workout.duration > 0 else {
            return nil
        }

        // Only workouts built with HKWorkoutBuilder (Apple Watch runs) carry
        // attached HR statistics; others return nil and simply show no HR.
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let avgHeartRate = normalizedHeartRate(
            bpm: workout.statistics(for: HKQuantityType(.heartRate))?
                .averageQuantity()?.doubleValue(for: bpmUnit)
        )
        let elevationGainMeters = normalizedElevationGain(
            meters: (workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?
                .doubleValue(for: .meter())
        )

        return RunWorkout(
            id: workout.uuid,
            startDate: workout.startDate,
            endDate: workout.endDate,
            distanceMeters: meters,
            duration: workout.duration,
            source: workout.sourceRevision.source.name,
            avgHeartRate: avgHeartRate,
            elevationGainMeters: elevationGainMeters
        )
    }

    /// Rounds a raw average-bpm reading to a whole heart rate, rejecting the
    /// missing/garbage cases (no sample, zero, negative, NaN, infinite).
    nonisolated static func normalizedHeartRate(bpm: Double?) -> Int? {
        guard let bpm, bpm.isFinite, bpm > 0 else { return nil }
        return Int(bpm.rounded())
    }

    /// Rejects absent and corrupt ascent samples while preserving a legitimate
    /// zero from flat treadmill or track workouts.
    nonisolated static func normalizedElevationGain(meters: Double?) -> Double? {
        guard let meters, meters.isFinite, meters >= 0 else { return nil }
        return meters
    }

}
