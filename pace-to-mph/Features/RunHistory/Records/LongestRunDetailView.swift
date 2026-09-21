import Charts
import SwiftUI

/// History of the longest-run record: the current longest, the run it
/// replaced, and every run that went farther than all before it.
struct LongestRunDetailView: View {
    let milestones: [RunLongestRunMilestone]
    let unit: SpeedUnit

    @Environment(\.dismiss) private var dismiss

    private var current: RunLongestRunMilestone? { milestones.last }
    private var previous: RunLongestRunMilestone? { milestones.dropLast().last }
    private var newestFirst: [RunLongestRunMilestone] { milestones.reversed() }

    private var distanceDomain: ClosedRange<Double> {
        guard let longest = milestones.map(\.distance).max(), longest > 0 else { return 0...1 }
        return 0...(longest * 1.15)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let current {
                        currentCard(current)

                        if let previous {
                            previousLongestCard(current: current, previous: previous)
                        } else {
                            firstRecordCard
                        }

                        if milestones.count >= 3 {
                            progressionChart
                        }

                        if milestones.count >= 2 {
                            progressionList
                        }
                    } else {
                        ContentUnavailableView(
                            "No runs yet",
                            systemImage: "rosette",
                            description: Text("Your longest run shows here once you log one.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Longest Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .accessibilityIdentifier("run-history-longest-detail")
        }
        .tint(.green)
    }

    private func currentCard(_ milestone: RunLongestRunMilestone) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "rosette")
                    .imageScale(.small)
                    .foregroundStyle(.green)
                Text("Current record")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(milestone.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(milestone.distanceValueText)
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit.distanceLabel)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                Label(milestone.timeText, systemImage: RunHistorySymbols.duration)
                Label("\(milestone.paceText) \(unit.paceLabel)", systemImage: RunHistorySymbols.pace)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current longest run, \(milestone.distanceText), set \(RunHistoryFormatters.longDate(milestone.date))")
        .accessibilityIdentifier("run-history-longest-current")
    }

    private func previousLongestCard(
        current: RunLongestRunMilestone,
        previous: RunLongestRunMilestone
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Previous longest")
                .font(.headline)

            HStack(alignment: .top, spacing: 12) {
                RecordMarkColumn(
                    value: previous.distanceText,
                    detail: previous.timeText,
                    date: previous.date,
                    isCurrent: false
                )

                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)

                RecordMarkColumn(
                    value: current.distanceText,
                    detail: current.timeText,
                    date: current.date,
                    isCurrent: true
                )

                Spacer(minLength: 0)
            }

            if let extra = current.extraDistanceText {
                Label(extra, systemImage: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.12), in: .capsule)
            }

            if let stood = current.previousStoodText {
                Text(stood)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("run-history-longest-previous")
    }

    private var firstRecordCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("First one on the board")
                .font(.headline)
            Text("Your first recorded run is still your longest. Go farther to set a new record.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    private var progressionChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Longest run over time")
                .font(.headline)

            Chart(milestones) { milestone in
                LineMark(
                    x: .value("Date", milestone.date),
                    y: .value("Distance", milestone.distance)
                )
                .interpolationMethod(.stepEnd)
                .foregroundStyle(Color.green)
                .lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Date", milestone.date),
                    y: .value("Distance", milestone.distance)
                )
                .foregroundStyle(Color.green)
                .symbolSize(40)
            }
            .chartYScale(domain: distanceDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 160)

            Text("Each step is a new longest run. Higher is farther.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("run-history-longest-progression")
    }

    private var progressionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Every record")
                    .font(.headline)
                Spacer()
                Text("\(milestones.count) marks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            ForEach(Array(newestFirst.enumerated()), id: \.element.id) { index, milestone in
                milestoneRow(milestone, isCurrent: index == 0)
                if index < newestFirst.count - 1 {
                    Divider()
                        .padding(.vertical, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("run-history-longest-list")
    }

    private func milestoneRow(_ milestone: RunLongestRunMilestone, isCurrent: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(milestone.distanceText)
                        .font(.headline)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                    if isCurrent {
                        Text("PR")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15), in: .capsule)
                    }
                }
                Text("\(milestone.timeText) · \(milestone.paceText) \(unit.paceLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(milestone.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let extra = milestone.extraDistanceText {
                    Text(extra)
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .monospacedDigit()
                } else {
                    Text("First on record")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
