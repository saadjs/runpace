import Foundation

extension RunHistoryStats {
    static func personalRecords(from runs: [RunWorkout], unit: SpeedUnit, referenceDate: Date = Date()) -> [RunPersonalRecord] {
        RunRecordTarget.allCases.filter { $0.isVisible(in: unit) }.compactMap { target in
            let efforts = efforts(for: target, runs: runs, unit: unit)
            // A later tie did not set a new record, so retain the first run that
            // achieved the best speed. This also matches recordProgression.
            guard let best = efforts.sorted(by: {
                if $0.speed != $1.speed { return $0.speed > $1.speed }
                return $0.date < $1.date
            }).first else { return nil }
            let baselineCutoff = calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
            let baseline = efforts
                .filter { $0.date < baselineCutoff }
                .max(by: { $0.speed < $1.speed })
            let pace = best.durationMinutes / target.distance(for: unit)

            return RunPersonalRecord(
                id: target.id,
                target: target,
                unit: unit,
                runID: best.runID,
                speed: best.speed,
                paceText: ConversionEngine.formatPace(pace) ?? "--",
                deltaSpeed: best.speed - (baseline?.speed ?? best.speed),
                achievedDate: best.date
            )
        }
    }

    /// Maps each run to every personal-record target it holds, so PR badges in
    /// the Runs list can render independently of the Trends tab selection. Built
    /// from `personalRecords`, so it inherits unit visibility and target order.
    static func personalRecordTargets(
        from runs: [RunWorkout],
        unit: SpeedUnit,
        referenceDate: Date = Date()
    ) -> [UUID: [RunRecordTarget]] {
        personalRecordTargets(from: personalRecords(from: runs, unit: unit, referenceDate: referenceDate))
    }

    /// Overload for callers that already hold the records, so a single view
    /// update never scans the full history for PRs more than once.
    static func personalRecordTargets(from records: [RunPersonalRecord]) -> [UUID: [RunRecordTarget]] {
        var map: [UUID: [RunRecordTarget]] = [:]
        for record in records {
            map[record.runID, default: []].append(record.target)
        }
        return map
    }


    /// Every badge the Runs list shows, keyed by run: named-distance PRs first,
    /// then the longest-run record.
    static func prBadges(from records: [RunPersonalRecord], longestRunID: UUID?) -> [UUID: [RunPRBadge]] {
        var map = personalRecordTargets(from: records).mapValues { $0.map(RunPRBadge.record) }
        if let longestRunID {
            map[longestRunID, default: []].append(.longestRun)
        }
        return map
    }

    /// The farthest run on record. A later run of the same distance did not set
    /// a new record, so ties keep the earlier run, matching `longestRunProgression`.
    static func longestRun(from runs: [RunWorkout]) -> RunWorkout? {
        runs.filter { $0.distanceMeters > 0 }.min {
            if $0.distanceMeters != $1.distanceMeters { return $0.distanceMeters > $1.distanceMeters }
            return $0.startDate < $1.startDate
        }
    }

    /// Returns each run that went farther than any run before it, oldest first.
    static func longestRunProgression(from runs: [RunWorkout], unit: SpeedUnit) -> [RunLongestRunMilestone] {
        let ordered = runs.filter { $0.distanceMeters > 0 }.sorted { $0.startDate < $1.startDate }
        var milestones: [RunLongestRunMilestone] = []
        var standing: RunWorkout?

        for run in ordered {
            if let standing, run.distanceMeters <= standing.distanceMeters { continue }
            milestones.append(
                RunLongestRunMilestone(
                    id: run.id,
                    unit: unit,
                    date: run.startDate,
                    distanceMeters: run.distanceMeters,
                    duration: run.duration,
                    previousDate: standing?.startDate,
                    previousDistanceMeters: standing?.distanceMeters
                )
            )
            standing = run
        }

        return milestones
    }

    /// Returns each effort that beat the standing record, oldest first.
    static func recordProgression(
        for target: RunRecordTarget,
        from runs: [RunWorkout],
        unit: SpeedUnit
    ) -> [RunRecordMilestone] {
        let ordered = efforts(for: target, runs: runs, unit: unit).sorted { $0.date < $1.date }
        var milestones: [RunRecordMilestone] = []
        var standing: RunRecordEffort?

        for effort in ordered {
            if let standing, effort.speed <= standing.speed { continue }
            milestones.append(
                RunRecordMilestone(
                    id: effort.runID,
                    target: target,
                    unit: unit,
                    date: effort.date,
                    speed: effort.speed,
                    durationMinutes: effort.durationMinutes,
                    isEstimated: effort.distanceMeters > target.meters,
                    previousDate: standing?.date,
                    previousDurationMinutes: standing?.durationMinutes
                )
            )
            standing = effort
        }

        return milestones
    }

    private static func efforts(for target: RunRecordTarget, runs: [RunWorkout], unit: SpeedUnit) -> [RunRecordEffort] {
        runs.compactMap { run in
            guard run.distanceMeters >= target.meters, run.duration > 0 else { return nil }
            let distance = target.distance(for: unit)
            let estimatedDuration = run.duration * (target.meters / run.distanceMeters)
            let speed = distance / (estimatedDuration / 3600.0)
            return RunRecordEffort(
                runID: run.id,
                date: run.startDate,
                speed: speed,
                durationMinutes: estimatedDuration / 60.0,
                distanceMeters: run.distanceMeters
            )
        }
    }
}
private struct RunRecordEffort {
    let runID: UUID
    let date: Date
    let speed: Double
    let durationMinutes: Double
    let distanceMeters: Double
}
