import Foundation
import SwiftData

@MainActor
final class RunWorkoutStore {
    nonisolated static let runningWorkoutsStateKey = "healthkit.runningWorkouts"

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchRuns() throws -> [RunWorkout] {
        let descriptor = FetchDescriptor<StoredRunWorkout>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).compactMap(\.runWorkout)
    }

    func applyChanges(
        upserting runs: [RunWorkout],
        deleting deletedIDs: [UUID],
        anchorData: Data?,
        stateKey: String = RunWorkoutStore.runningWorkoutsStateKey,
        syncedAt: Date = Date()
    ) throws {
        for run in runs {
            if let stored = try storedRun(with: run.id) {
                stored.update(from: run, syncedAt: syncedAt)
            } else {
                modelContext.insert(StoredRunWorkout(run: run, syncedAt: syncedAt))
            }
        }

        for id in deletedIDs {
            if let stored = try storedRun(with: id) {
                modelContext.delete(stored)
            }
        }

        let state = try syncState(for: stateKey)
        state.anchorData = anchorData
        state.lastSyncedAt = syncedAt

        try modelContext.save()
    }

    func anchorData(for key: String = RunWorkoutStore.runningWorkoutsStateKey) throws -> Data? {
        try syncState(for: key).anchorData
    }

    func lastSyncedAt(for key: String = RunWorkoutStore.runningWorkoutsStateKey) throws -> Date? {
        try syncState(for: key).lastSyncedAt
    }

    func didRequestAuthorization(for key: String = RunWorkoutStore.runningWorkoutsStateKey) throws -> Bool {
        try syncState(for: key).didRequestAuthorization
    }

    func markAuthorizationRequested(for key: String = RunWorkoutStore.runningWorkoutsStateKey) throws {
        let state = try syncState(for: key)
        state.didRequestAuthorization = true
        try modelContext.save()
    }

    func didRequestHeartRate(for key: String = RunWorkoutStore.runningWorkoutsStateKey) throws -> Bool {
        try syncState(for: key).didRequestHeartRate
    }

    func markHeartRateRequested(for key: String = RunWorkoutStore.runningWorkoutsStateKey) throws {
        let state = try syncState(for: key)
        state.didRequestHeartRate = true
        try modelContext.save()
    }

    private func storedRun(with id: UUID) throws -> StoredRunWorkout? {
        let idString = id.uuidString
        var descriptor = FetchDescriptor<StoredRunWorkout>(
            predicate: #Predicate { run in
                run.healthKitUUIDString == idString
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func syncState(for key: String) throws -> RunSyncState {
        var descriptor = FetchDescriptor<RunSyncState>(
            predicate: #Predicate { state in
                state.key == key
            }
        )
        descriptor.fetchLimit = 1

        if let state = try modelContext.fetch(descriptor).first {
            return state
        }

        let state = RunSyncState(key: key)
        modelContext.insert(state)
        try modelContext.save()
        return state
    }
}
