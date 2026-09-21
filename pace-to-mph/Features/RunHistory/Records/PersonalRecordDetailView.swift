import Charts
import SwiftUI

struct PersonalRecordDetailView: View {
    let target: RunRecordTarget
    let milestones: [RunRecordMilestone]
    let unit: SpeedUnit

    @Environment(\.dismiss) private var dismiss

    private var current: RunRecordMilestone? { milestones.last }
    private var previous: RunRecordMilestone? { milestones.dropLast().last }
    private var newestFirst: [RunRecordMilestone] { milestones.reversed() }

    private var timeDomain: ClosedRange<Double> {
        let times = milestones.map(\.durationMinutes)
        guard let fastest = times.min(), let slowest = times.max() else { return 0...1 }
        let padding = max((slowest - fastest) * 0.25, 0.25)
        return max(0, fastest - padding)...(slowest + padding)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let current {
                        currentCard(current)

                        if let previous {
                            previousBestCard(current: current, previous: previous)
                        } else {
                            firstRecordCard
                        }

                        if milestones.count >= 3 {
                            progressionChart
                        }

                        if milestones.count >= 2 {
                            progressionList
                        }

                        footnote
                    } else {
                        ContentUnavailableView(
                            "No \(target.displayName) yet",
                            systemImage: "rosette",
                            description: Text("Run at least \(target.distanceCopy) to set your first record.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("\(target.displayName) Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .accessibilityIdentifier("run-history-record-detail")
        }
        .tint(.green)
    }

    private func currentCard(_ milestone: RunRecordMilestone) -> some View {
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

            Text(milestone.timeText)
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 14) {
                Label("\(milestone.paceText) \(unit.paceLabel)", systemImage: RunHistorySymbols.pace)
                Label("\(milestone.speedText) \(unit.speedLabel)", systemImage: RunHistorySymbols.speed)
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
        .accessibilityLabel("Current \(target.displayName) record, \(milestone.timeText), set \(RunHistoryFormatters.longDate(milestone.date))")
        .accessibilityIdentifier("run-history-record-current")
    }

    private func previousBestCard(current: RunRecordMilestone, previous: RunRecordMilestone) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Previous best")
                .font(.headline)

            HStack(alignment: .top, spacing: 12) {
                RecordMarkColumn(
                    value: previous.timeText,
                    detail: "\(previous.paceText) \(unit.paceLabel)",
                    date: previous.date,
                    isCurrent: false
                )

                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)

                RecordMarkColumn(
                    value: current.timeText,
                    detail: "\(current.paceText) \(unit.paceLabel)",
                    date: current.date,
                    isCurrent: true
                )

                Spacer(minLength: 0)
            }

            if let improvement = current.improvementText {
                HStack(spacing: 8) {
                    Label(improvement, systemImage: "arrow.down.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.12), in: .capsule)

                    if let paceImprovement = current.paceImprovementText {
                        Text(paceImprovement)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
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
        .accessibilityIdentifier("run-history-record-previous")
    }

    private var firstRecordCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("First one on the board")
                .font(.headline)
            Text("This was the first record for \(target.displayName), and no later qualifying effort has beaten it yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    private var progressionChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Record over time")
                .font(.headline)

            Chart(milestones) { milestone in
                LineMark(
                    x: .value("Date", milestone.date),
                    y: .value("Time", milestone.durationMinutes)
                )
                .interpolationMethod(.stepEnd)
                .foregroundStyle(Color.green)
                .lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Date", milestone.date),
                    y: .value("Time", milestone.durationMinutes)
                )
                .foregroundStyle(Color.green)
                .symbolSize(40)
            }
            .chartYScale(domain: timeDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let minutes = value.as(Double.self) {
                            Text(RunHistoryFormatters.duration(minutes * 60))
                        }
                    }
                }
            }
            .frame(height: 160)

            Text("Each step is a new record. Lower is faster.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("run-history-record-progression")
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
        .accessibilityIdentifier("run-history-record-list")
    }

    private func milestoneRow(_ milestone: RunRecordMilestone, isCurrent: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(milestone.timeText)
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
                    if milestone.isEstimated {
                        Text("est.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text("\(milestone.paceText) \(unit.paceLabel) · \(milestone.speedText) \(unit.speedLabel)")
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
                if let improvement = milestone.improvementText {
                    Text(improvement)
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

    private var footnote: some View {
        Text("Efforts marked \"est.\" come from longer runs, timed at that run's average pace over \(target.distanceCopy).")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
