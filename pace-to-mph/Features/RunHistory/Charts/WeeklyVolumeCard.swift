import Charts
import SwiftUI

struct WeeklyVolumeCard: View {
    let bars: [RunVolumeBar]
    let cadence: RunCadence
    let scope: RunTrendScope
    let unit: SpeedUnit

    @State private var selectedDate: Date?

    private var selectedBar: RunVolumeBar? {
        guard let selectedDate else { return nil }
        return bars.nearest(to: selectedDate, by: \.periodStart)
    }

    private var title: String {
        scope.bucketing == .weekly ? "Weekly Volume" : "Monthly Volume"
    }

    private var subtitle: String {
        let unitWord = unit == .mph ? "miles" : "kilometres"
        let interval = scope.bucketing == .weekly ? "week" : "month"
        return "Total \(unitWord) per \(interval)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(scope.menuLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Label(subtitle, systemImage: RunHistorySymbols.distance)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if bars.isEmpty {
                Text("No runs in this period.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                chart
                    .frame(height: 120)
                if let selectedBar {
                    selectedStats(for: selectedBar)
                        .accessibilityIdentifier("run-history-volume-selection")
                } else {
                    statsRow
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("run-history-volume-chart")
        .sensoryFeedback(.selection, trigger: selectedBar?.id)
        .onChange(of: bars) { _, _ in selectedDate = nil }
    }

    private var chart: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Period", bar.periodStart, unit: scope.bucketing == .weekly ? .weekOfYear : .month),
                    y: .value("Distance", bar.distance)
                )
                .foregroundStyle(Color.green.gradient)
                .opacity(selectedBar == nil || selectedBar?.id == bar.id ? 1 : 0.35)
                .cornerRadius(4)
            }

            if let selectedBar {
                RuleMark(
                    x: .value(
                        "Selected period",
                        selectedBar.periodStart,
                        unit: scope.bucketing == .weekly ? .weekOfYear : .month
                    )
                )
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(.init(lineWidth: 1))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            ChartScrubOverlay(
                proxy: proxy,
                onScrub: selectNearestBar(to:),
                onEnd: { selectedDate = nil }
            )
        }
        .accessibilityIdentifier("run-history-volume-plot")
    }

    // Bars are drawn across a whole week/month, so snap on the bucket's midpoint
    // rather than its start — otherwise the second half of a bar selects its
    // neighbour.
    private func selectNearestBar(to date: Date) {
        guard let nearest = bars.nearest(to: date, by: { bucketCenter(for: $0.periodStart) })
        else { return }

        if selectedBar?.id != nearest.id {
            selectedDate = nearest.periodStart
        }
    }

    private func bucketCenter(for start: Date) -> Date {
        let component: Calendar.Component = scope.bucketing == .weekly ? .weekOfYear : .month
        guard let end = RunHistoryStats.calendar.date(byAdding: component, value: 1, to: start) else {
            return start
        }
        return start.addingTimeInterval(end.timeIntervalSince(start) / 2)
    }

    private func selectedStats(for bar: RunVolumeBar) -> some View {
        let unitLabel = unit == .mph ? "mi" : "km"
        return VStack(spacing: 8) {
            Text(periodTitle(for: bar.periodStart))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: 0) {
                statBlock(
                    value: String(format: "%.1f", bar.distance),
                    label: unitLabel,
                    systemImage: RunHistorySymbols.distance
                )
                Divider().frame(height: 32)
                statBlock(
                    value: "\(bar.runCount)",
                    label: bar.runCount == 1 ? "run" : "runs",
                    systemImage: RunHistorySymbols.runs
                )
                Divider().frame(height: 32)
                statBlock(
                    value: bar.paceText,
                    label: "avg \(unit.paceLabel)",
                    systemImage: RunHistorySymbols.pace
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(periodTitle(for: bar.periodStart)), \(bar.runCount) runs, \(String(format: "%.1f", bar.distance)) \(unitLabel), average pace \(bar.paceText) \(unit.paceLabel)")
    }

    private func periodTitle(for start: Date) -> String {
        if scope.bucketing == .monthly {
            return start.formatted(.dateTime.month(.wide).year())
        }
        let end = RunHistoryStats.calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return RunHistoryFormatters.weekRange(start, end)
    }

    /// Both averages divide by the scope's elapsed span — not by the number of
    /// bars — so a period the runner sat out still counts against the average,
    /// and the runs/wk here matches the one on the Activity card above.
    private var statsRow: some View {
        let total = bars.reduce(0.0) { $0 + $1.distance }
        let isWeekly = scope.bucketing == .weekly
        let periods = isWeekly ? cadence.weeks : cadence.months
        let averageDistance = periods > 0 ? total / periods : 0
        let averageRuns = isWeekly ? cadence.runsPerWeek : cadence.runsPerMonth
        let unitLabel = unit == .mph ? "mi" : "km"
        let intervalLabel = isWeekly ? "wk" : "mo"
        return HStack(alignment: .top, spacing: 0) {
            statBlock(
                value: String(format: "%.1f", total),
                label: "Total \(unitLabel)",
                systemImage: RunHistorySymbols.distance
            )
            Divider().frame(height: 32)
            statBlock(
                value: String(format: "%.1f", averageDistance),
                label: "\(unitLabel) / \(intervalLabel)",
                systemImage: RunHistorySymbols.distance
            )
            Divider().frame(height: 32)
            statBlock(
                value: String(format: "%.1f", averageRuns),
                label: "runs / \(intervalLabel)",
                systemImage: RunHistorySymbols.runs
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func statBlock(value: String, label: String, systemImage: String? = nil) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 3) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(label)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
