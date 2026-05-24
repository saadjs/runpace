import Foundation
import HealthKit
import SwiftData

@Observable
@MainActor
final class HealthKitService {
    enum AuthorizationState {
        case notDetermined
        case denied
        case authorized
        case unavailable
    }

    private let healthStore = HKHealthStore()
    private var runStore: RunWorkoutStore?
    private var observerQuery: HKObserverQuery?

    var authorizationState: AuthorizationState = .notDetermined
    var runs: [RunWorkout] = []
    var isLoading: Bool = false
    var lastError: String?

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        types.insert(HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!)
        return types
    }

    func configure(modelContext: ModelContext) {
        guard runStore == nil else { return }
        runStore = RunWorkoutStore(modelContext: modelContext)
    }

    func bootstrap() async {
        loadCachedRuns()
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }

        let didRequestAuthorization = (try? runStore?.didRequestAuthorization()) ?? false
        // HealthKit doesn't expose read-auth status. A previous successful request or cached workouts
        // is our durable signal that the app can sync without prompting again.
        if didRequestAuthorization || !runs.isEmpty {
            authorizationState = .authorized
        }
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            try runStore?.markAuthorizationRequested()
            authorizationState = .authorized
            await refresh()
            startObserving()
        } catch {
            lastError = error.localizedDescription
            authorizationState = .denied
        }
    }

    // User-triggered / view-appearance refreshes use a nil anchor (full sync)
    // so we self-heal from two cases HealthKit hides from us: read-denial
    // poisoning the anchor with 0 results, and silent revocation after a
    // successful sync (cache would otherwise show stale ghost data forever).
    // The observer query path passes fullSync: false for incremental sync.
    func refresh(fullSync: Bool = true) async {
        guard HKHealthStore.isHealthDataAvailable() else {
            loadCachedRuns()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let runStore else {
                let changes = try await fetchRunningWorkoutChanges(anchor: nil)
                runs = changes.workouts.sorted { $0.startDate > $1.startDate }
                authorizationState = .authorized
                return
            }

            let anchor: HKQueryAnchor? = fullSync ? nil : try storedAnchor()
            let changes = try await fetchRunningWorkoutChanges(anchor: anchor)

            let deletedIDs: [UUID]
            if fullSync {
                let fetchedIDs = Set(changes.workouts.map(\.id))
                let cachedIDs = try runStore.fetchRuns().map(\.id)
                deletedIDs = cachedIDs.filter { !fetchedIDs.contains($0) }
            } else {
                deletedIDs = changes.deletedIDs
            }

            try runStore.applyChanges(
                upserting: changes.workouts,
                deleting: deletedIDs,
                anchorData: try Self.archiveAnchor(changes.anchor)
            )
            loadCachedRuns()
            authorizationState = .authorized
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func loadCachedRuns() {
        do {
            if let cachedRuns = try runStore?.fetchRuns() {
                runs = cachedRuns
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func storedAnchor() throws -> HKQueryAnchor? {
        guard let data = try runStore?.anchorData() else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        } catch {
            try runStore?.applyChanges(upserting: [], deleting: [], anchorData: nil)
            return nil
        }
    }

    private func fetchRunningWorkoutChanges(anchor: HKQueryAnchor?) async throws -> RunningWorkoutChanges {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .running)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: workoutType,
                predicate: predicate,
                anchor: anchor,
                limit: HKObjectQueryNoLimit,
                resultsHandler: { _, samples, deletedObjects, newAnchor, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let workouts = (samples as? [HKWorkout]) ?? []
                    let imported = workouts.reduce(into: (runs: [RunWorkout](), invalidIDs: [UUID]())) { result, workout in
                        if let run = Self.mapImportableWorkout(workout) {
                            result.runs.append(run)
                        } else {
                            result.invalidIDs.append(workout.uuid)
                        }
                    }
                    let deletedIDs = (deletedObjects ?? []).map(\.uuid) + imported.invalidIDs
                    continuation.resume(
                        returning: RunningWorkoutChanges(
                            workouts: imported.runs,
                            deletedIDs: deletedIDs,
                            anchor: newAnchor
                        )
                    )
                }
            )
            healthStore.execute(query)
        }
    }

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
        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let query = HKObserverQuery(sampleType: workoutType, predicate: predicate) { [weak self] _, completionHandler, error in
            let message = error?.localizedDescription
            Task { @MainActor [weak self] in
                defer { completionHandler() }
                if let message {
                    self?.lastError = message
                    return
                }
                await self?.refresh(fullSync: false)
            }
        }
        healthStore.execute(query)
        observerQuery = query

        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { [weak self] _, error in
            if let error {
                let message = error.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.lastError = message
                }
            }
        }
    }

    private static func archiveAnchor(_ anchor: HKQueryAnchor?) throws -> Data? {
        guard let anchor else { return nil }
        return try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    }
}

private struct RunningWorkoutChanges {
    let workouts: [RunWorkout]
    let deletedIDs: [UUID]
    let anchor: HKQueryAnchor?
}
