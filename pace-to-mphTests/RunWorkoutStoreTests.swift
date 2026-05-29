import Foundation
import SwiftData
import Testing
@testable import pace_to_mph

@MainActor
struct RunWorkoutStoreTests {
    @Test func persistenceRoundTripPreservesCalculatedSummary() throws {
        let store = try makeStore()
        let run = makeRun(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            startDate: Date(timeIntervalSince1970: 1_779_552_000),
            distanceMeters: 5_000,
            duration: 1_500
        )

        try store.applyChanges(upserting: [run], deleting: [], anchorData: nil)

        let persisted = try #require(try store.fetchRuns().first)
        #expect(persisted.id == run.id)
        #expect(persisted.startDate == run.startDate)
        #expect(persisted.endDate == run.endDate)
        #expect(abs(persisted.distanceMeters - run.distanceMeters) < 0.001)
        #expect(abs(persisted.duration - run.duration) < 0.001)
        #expect(persisted.source == run.source)

        let originalSummary = RunHistoryStats.summary(from: [run], unit: .mph)
        let persistedSummary = RunHistoryStats.summary(from: [persisted], unit: .mph)
        #expect(persistedSummary == originalSummary)
        #expect(abs(persisted.averageSpeedMph - run.averageSpeedMph) < 0.0001)
    }

    @Test func duplicateHealthKitUUIDUpsertsInsteadOfDoubleCounting() throws {
        let store = try makeStore()
        let id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let original = makeRun(id: id, distanceMeters: 5_000, duration: 1_500)
        let updated = makeRun(id: id, distanceMeters: 6_000, duration: 1_800)

        try store.applyChanges(upserting: [original], deleting: [], anchorData: nil)
        try store.applyChanges(upserting: [updated], deleting: [], anchorData: nil)

        let runs = try store.fetchRuns()
        #expect(runs.count == 1)
        #expect(runs.first?.id == id)
        #expect(runs.first?.distanceMeters == 6_000)

        let summary = RunHistoryStats.summary(from: runs, unit: .kph)
        #expect(summary.runCount == 1)
        #expect(summary.distanceText == "6.0")
    }

    @Test func deletedHealthKitUUIDRemovesCachedRun() throws {
        let store = try makeStore()
        let deletedID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let retainedID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let deleted = makeRun(id: deletedID, distanceMeters: 3_000, duration: 900)
        let retained = makeRun(id: retainedID, distanceMeters: 4_000, duration: 1_200)

        try store.applyChanges(upserting: [deleted, retained], deleting: [], anchorData: nil)
        try store.applyChanges(upserting: [], deleting: [deletedID], anchorData: nil)

        let runs = try store.fetchRuns()
        #expect(runs.count == 1)
        #expect(runs.first?.id == retainedID)
    }

    @Test func syncStatePersistsAnchorAndAuthorizationFlag() throws {
        let store = try makeStore()
        let anchorData = Data([1, 2, 3, 4])

        try store.applyChanges(upserting: [], deleting: [], anchorData: anchorData)
        try store.markAuthorizationRequested()

        #expect(try store.anchorData() == anchorData)
        #expect(try store.didRequestAuthorization())
    }

    @Test func personalRecordsHideOppositeUnitOnlyTargets() {
        let run = makeRun(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            distanceMeters: 42_195,
            duration: 14_400
        )

        let mphTargetIDs = Set(RunHistoryStats.personalRecords(from: [run], unit: .mph).map(\.target.id))
        let kphTargetIDs = Set(RunHistoryStats.personalRecords(from: [run], unit: .kph).map(\.target.id))
        let sharedTargetIDs = [
            RunRecordTarget.fiveKilometers.id,
            RunRecordTarget.tenKilometers.id,
            RunRecordTarget.halfMarathon.id,
            RunRecordTarget.marathon.id
        ]

        #expect(mphTargetIDs.contains(RunRecordTarget.oneMile.id))
        #expect(!mphTargetIDs.contains(RunRecordTarget.oneKilometer.id))
        #expect(kphTargetIDs.contains(RunRecordTarget.oneKilometer.id))
        #expect(!kphTargetIDs.contains(RunRecordTarget.oneMile.id))
        #expect(sharedTargetIDs.allSatisfy { mphTargetIDs.contains($0) })
        #expect(sharedTargetIDs.allSatisfy { kphTargetIDs.contains($0) })
    }

    @Test func personalRecordTargetsMapsEachRunToAllItsPRsIndependentOfSelection() {
        // Fast short run wins the shorter targets; slow long run wins the
        // longer ones. Both runs end up holding multiple PRs simultaneously.
        let fastShort = makeRun(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            distanceMeters: 5_000,
            duration: 1_200
        )
        let slowLong = makeRun(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            distanceMeters: 42_195,
            duration: 14_400
        )

        let map = RunHistoryStats.personalRecordTargets(from: [fastShort, slowLong], unit: .mph)

        // The map is derived from runs alone — no Trends selection feeds into it.
        #expect(map[fastShort.id] == [.oneMile, .fiveKilometers])
        #expect(map[slowLong.id] == [.tenKilometers, .halfMarathon, .marathon])
    }

    private func makeStore() throws -> RunWorkoutStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: StoredRunWorkout.self,
            RunSyncState.self,
            configurations: configuration
        )
        return RunWorkoutStore(modelContext: ModelContext(container))
    }

    private func makeRun(
        id: UUID,
        startDate: Date = Date(timeIntervalSince1970: 1_779_552_000),
        distanceMeters: Double,
        duration: TimeInterval
    ) -> RunWorkout {
        RunWorkout(
            id: id,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(duration),
            distanceMeters: distanceMeters,
            duration: duration,
            source: "RunPace Tests"
        )
    }
}
