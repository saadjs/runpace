import Foundation
import HealthKit

@Observable
@MainActor
final class HealthKitService {
    enum AuthorizationState {
        case notDetermined
        case denied
        case authorized
        case unavailable
    }

    private let store = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var anchor: HKQueryAnchor?

    var authorizationState: AuthorizationState = .notDetermined
    var runs: [RunWorkout] = []
    var isLoading: Bool = false
    var lastError: String?

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        types.insert(HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!)
        return types
    }

    func bootstrap() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }
        // We can't reliably know read-auth status; if we've previously fetched, treat as authorized.
        // Otherwise leave as notDetermined so the user is prompted.
        if !runs.isEmpty {
            authorizationState = .authorized
        }
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authorizationState = .authorized
            await refresh()
            startObserving()
        } catch {
            lastError = error.localizedDescription
            authorizationState = .denied
        }
    }

    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let workouts = try await fetchRunningWorkouts()
            runs = workouts
            if !workouts.isEmpty {
                authorizationState = .authorized
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func fetchRunningWorkouts() async throws -> [RunWorkout] {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                let mapped = workouts.map { Self.mapWorkout($0) }
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }

    private static func mapWorkout(_ workout: HKWorkout) -> RunWorkout {
        let meters: Double = {
            if let stats = workout.statistics(for: HKQuantityType(.distanceWalkingRunning)),
               let sum = stats.sumQuantity() {
                return sum.doubleValue(for: .meter())
            }
            // Fallback for older samples.
            return workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        }()
        return RunWorkout(
            id: workout.uuid,
            startDate: workout.startDate,
            endDate: workout.endDate,
            distanceMeters: meters,
            duration: workout.duration,
            source: workout.sourceRevision.source.name
        )
    }

    // MARK: - Auto-import (background delivery)

    func startObserving() {
        guard observerQuery == nil else { return }
        let workoutType = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
            if error == nil {
                Task { @MainActor in
                    await self?.refresh()
                }
            }
            completionHandler()
        }
        store.execute(query)
        observerQuery = query

        store.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
    }
}
