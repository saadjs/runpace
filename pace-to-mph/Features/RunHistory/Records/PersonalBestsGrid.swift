import Charts
import SwiftUI

struct PersonalBestsGrid: View {
    let records: [RunPersonalRecord]
    let runs: [RunWorkout]
    let unit: SpeedUnit

    @State private var selection: PersonalBestSelection?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var longestRunMilestones: [RunLongestRunMilestone] {
        RunHistoryStats.longestRunProgression(from: runs, unit: unit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Personal Bests")
                    .font(.headline)
                Spacer()
                Text("All time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(records) { record in
                    Button {
                        selection = .record(record)
                    } label: {
                        PBCell(
                            title: record.target.displayName,
                            value: record.speedText,
                            valueUnit: unit.speedLabel,
                            detail: "\(record.paceText) \(unit.paceLabel)",
                            date: record.achievedDate
                        )
                        .accessibilityLabel("\(record.target.displayName) personal best, \(record.speedText) \(unit.speedLabel)")
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows this record's history and the mark it beat")
                }

                if let longest = longestRunMilestones.last {
                    Button {
                        selection = .longestRun
                    } label: {
                        PBCell(
                            title: "Longest Run",
                            value: longest.distanceValueText,
                            valueUnit: unit.distanceLabel,
                            detail: "\(longest.timeText) · \(longest.paceText) \(unit.paceLabel)",
                            date: longest.date
                        )
                        .accessibilityLabel("Longest run personal best, \(longest.distanceText)")
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows every run that set a new longest distance")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("run-history-personal-bests")
        .sheet(item: $selection) { selection in
            switch selection {
            case .record(let record):
                PersonalRecordDetailView(
                    target: record.target,
                    milestones: RunHistoryStats.recordProgression(for: record.target, from: runs, unit: unit),
                    unit: unit
                )
            case .longestRun:
                LongestRunDetailView(milestones: longestRunMilestones, unit: unit)
            }
        }
    }
}

private enum PersonalBestSelection: Identifiable {
    case record(RunPersonalRecord)
    case longestRun

    var id: String {
        switch self {
        case .record(let record): return record.id
        case .longestRun: return "longest-run"
        }
    }
}

private struct PBCell: View {
    let title: String
    let value: String
    let valueUnit: String
    let detail: String
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Image(systemName: "rosette")
                    .imageScale(.small)
                    .foregroundStyle(.green)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(valueUnit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(date, format: .dateTime.month(.abbreviated).day().year())
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
