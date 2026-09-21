import SwiftUI

enum RunHistoryPreviewData {
    static let compactRuns: [RunWorkout] = [
        makeRun(daysAgo: 0, miles: 3.1, minutes: 24.8, avgHeartRate: 151, elevationGainMeters: 42),
        makeRun(daysAgo: 2, miles: 6.2, minutes: 52.5, avgHeartRate: 158, elevationGainMeters: 118),
        makeRun(daysAgo: 34, miles: 4.0, minutes: 34.0, avgHeartRate: 149, elevationGainMeters: nil),
        makeRun(daysAgo: 39, miles: 9.0, minutes: 85.0, avgHeartRate: 163, elevationGainMeters: 240),
        makeRun(daysAgo: 67, miles: 3.1, minutes: 26.0, avgHeartRate: 153, elevationGainMeters: 35),
        makeRun(daysAgo: 72, miles: 6.2, minutes: 55.0, avgHeartRate: 160, elevationGainMeters: 105),
        makeRun(daysAgo: 98, miles: 5.0, minutes: 44.0, avgHeartRate: 155, elevationGainMeters: nil),
        makeRun(daysAgo: 102, miles: 10.0, minutes: 96.0, avgHeartRate: 165, elevationGainMeters: 310),
        makeRun(daysAgo: 130, miles: 3.1, minutes: 27.2, avgHeartRate: 150, elevationGainMeters: 28),
        makeRun(daysAgo: 155, miles: 7.0, minutes: 66.0, avgHeartRate: 162, elevationGainMeters: 175)
    ].sorted { $0.startDate > $1.startDate }

    static let sparseRuns: [RunWorkout] = [
        makeRun(daysAgo: 1, miles: 3.1, minutes: 29.0, avgHeartRate: nil, elevationGainMeters: nil)
    ]

    // Regression scenario for the Trends UI: the five comparable 5K efforts
    // have gradually slowed, while the newest 3.58-mile run is substantially
    // faster. All Runs must include it; the 5K breakdown must not call it a 5K.
    static let mixedDistanceRuns: [RunWorkout] = [
        makeRun(daysAgo: 70, miles: 3.10, minutes: 24.8, avgHeartRate: 150),
        makeRun(daysAgo: 56, miles: 3.10, minutes: 25.4, avgHeartRate: 151),
        makeRun(daysAgo: 42, miles: 3.10, minutes: 26.0, avgHeartRate: 152),
        makeRun(daysAgo: 28, miles: 3.10, minutes: 26.7, avgHeartRate: 153),
        makeRun(daysAgo: 14, miles: 3.10, minutes: 27.3, avgHeartRate: 154),
        makeRun(daysAgo: 1, miles: 3.58, minutes: 23.3, avgHeartRate: 158)
    ].sorted { $0.startDate > $1.startDate }

    static let recordProgressionRuns: [RunWorkout] = [
        makeRun(daysAgo: 12, miles: 3.15, minutes: 24.63, avgHeartRate: 172, elevationGainMeters: 38),
        makeRun(daysAgo: 30, miles: 6.25, minutes: 54.08, avgHeartRate: 166, elevationGainMeters: 96),
        makeRun(daysAgo: 60, miles: 3.15, minutes: 25.83, avgHeartRate: 169, elevationGainMeters: 41),
        makeRun(daysAgo: 90, miles: 6.25, minutes: 55.20, avgHeartRate: 164, elevationGainMeters: 102),
        makeRun(daysAgo: 120, miles: 13.15, minutes: 123.50, avgHeartRate: 161, elevationGainMeters: 285),
        makeRun(daysAgo: 150, miles: 3.15, minutes: 27.17, avgHeartRate: 158, elevationGainMeters: 33),
        makeRun(daysAgo: 210, miles: 6.25, minutes: 59.67, avgHeartRate: 159, elevationGainMeters: 88),
        makeRun(daysAgo: 300, miles: 3.15, minutes: 26.67, avgHeartRate: 165, elevationGainMeters: 36),
        makeRun(daysAgo: 400, miles: 6.25, minutes: 58.50, avgHeartRate: 160, elevationGainMeters: 91),
        makeRun(daysAgo: 430, miles: 3.15, minutes: 28.92, avgHeartRate: 155, elevationGainMeters: nil),
        makeRun(daysAgo: 500, miles: 13.15, minutes: 132.00, avgHeartRate: 158, elevationGainMeters: 310),
        makeRun(daysAgo: 560, miles: 3.15, minutes: 28.33, avgHeartRate: 157, elevationGainMeters: 30),
        makeRun(daysAgo: 620, miles: 6.25, minutes: 62.00, avgHeartRate: 156, elevationGainMeters: 84),
        makeRun(daysAgo: 640, miles: 3.15, minutes: 29.17, avgHeartRate: 154, elevationGainMeters: nil),
        makeRun(daysAgo: 700, miles: 3.15, minutes: 30.00, avgHeartRate: 152, elevationGainMeters: 27)
    ].sorted { $0.startDate > $1.startDate }

    static let edgeCaseRuns: [RunWorkout] = [
        makeRun(daysAgo: 0, miles: 0.62, minutes: 6.5, avgHeartRate: nil, elevationGainMeters: 0),
        makeRun(daysAgo: 6, miles: 26.2, minutes: 255, avgHeartRate: 178, elevationGainMeters: 1_850),
        makeRun(daysAgo: 31, miles: 3.1, minutes: 28.5, avgHeartRate: 142, elevationGainMeters: nil),
        makeRun(daysAgo: 185, miles: 13.1, minutes: 125, avgHeartRate: 166, elevationGainMeters: 640),
        makeRun(daysAgo: 370, miles: 6.2, minutes: 61, avgHeartRate: 155, elevationGainMeters: 95),
        makeRun(daysAgo: 740, miles: 3.1, minutes: 31, avgHeartRate: nil, elevationGainMeters: nil)
    ].sorted { $0.startDate > $1.startDate }

    static let runs: [RunWorkout] = {
        // Roughly 18 months of training so every scope — and the per-week and
        // per-month averages that hang off them — has real spread to show:
        // three runs most weeks, an easy 5K / a mid-week 10K / a long run, with
        // the odd week skipped and a steady speed gain over time.
        var runs: [RunWorkout] = []
        let templates: [(offsetInWeek: Int, miles: Double, basePaceMinPerMile: Double, heartRate: Int?)] = [
            (0, 3.1, 8.6, 150),   // easy 5K
            (3, 6.2, 8.9, 159),   // mid-week 10K
            (5, 9.0, 9.6, 164)    // weekend long run
        ]

        for weeksAgo in 0..<78 {
            // Skip a week here and there so the weekly average isn't a flat 3.0.
            if weeksAgo % 7 == 4 { continue }
            let improvement = Double(weeksAgo) * 0.006  // older runs are slower
            let wobble = [0.0, 0.12, -0.08, 0.05, -0.14][weeksAgo % 5]

            for template in templates {
                // Drop the long run on lighter weeks.
                if template.offsetInWeek == 5 && weeksAgo % 3 == 2 { continue }
                let daysAgo = weeksAgo * 7 + (6 - template.offsetInWeek)
                guard daysAgo > 0 || weeksAgo == 0 else { continue }
                let pace = template.basePaceMinPerMile + improvement + wobble
                runs.append(
                    makeRun(
                        daysAgo: daysAgo,
                        miles: template.miles,
                        minutes: template.miles * pace,
                        avgHeartRate: template.heartRate,
                        elevationGainMeters: weeksAgo % 5 == 0
                            ? nil
                            : template.miles * (18 + Double(weeksAgo % 6) * 4)
                    )
                )
            }
        }

        // A couple of runs this week so the current-week section is populated.
        runs.append(makeRun(daysAgo: 0, miles: 3.1, minutes: 25.0, avgHeartRate: 152, elevationGainMeters: 45))
        runs.append(makeRun(daysAgo: 2, miles: 6.2, minutes: 53.0, avgHeartRate: 158, elevationGainMeters: 120))

        return runs.sorted { $0.startDate > $1.startDate }
    }()

    private static func makeRun(
        daysAgo: Int,
        miles: Double,
        minutes: Double,
        avgHeartRate: Int? = nil,
        elevationGainMeters: Double? = nil
    ) -> RunWorkout {
        let calendar = RunHistoryStats.calendar
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return RunWorkout(
            id: UUID(),
            startDate: start,
            endDate: start.addingTimeInterval(minutes * 60),
            distanceMeters: miles * 1609.34,
            duration: minutes * 60,
            source: "Preview",
            avgHeartRate: avgHeartRate,
            elevationGainMeters: elevationGainMeters
        )
    }
}

#Preview {
    NavigationStack {
        RunHistoryContent(runs: RunHistoryPreviewData.runs, unit: .mph)
            .navigationTitle("Run History")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
struct RunHistoryDebugPreviewView: View {
    let showTrends: Bool
    let showYearGroupingPrototypes: Bool

    init(
        showTrends: Bool = false,
        showYearGroupingPrototypes: Bool = false
    ) {
        self.showTrends = showTrends
        self.showYearGroupingPrototypes = showYearGroupingPrototypes
    }

    var body: some View {
        NavigationStack {
            RunHistoryContent(
                runs: RunHistoryPreviewData.runs,
                unit: .mph,
                initialMode: showTrends ? .trends : .runs,
                initialPeriod: showYearGroupingPrototypes ? .year : .week
            )
                .navigationTitle("Run History")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
