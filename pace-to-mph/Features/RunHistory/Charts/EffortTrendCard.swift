import Charts
import SwiftUI

/// Pairs heart rate with pace: heartbeats spent covering a mile/kilometre, run
/// by run, with a best-fit line. Speed alone can't tell improving fitness from
/// a hard day; this can, because holding the same pace at a calmer heart rate
/// pushes the line down. Scrub to inspect a single run.
struct EffortTrendCard: View {
    let trend: RunEffortTrend
    let scope: RunTrendScope
    let unit: SpeedUnit

    @State private var selectedPointID: String?

    private var selectedPoint: RunEffortPoint? {
        guard let selectedPointID else { return nil }
        return trend.points.first { $0.id == selectedPointID }
    }

    // Unlike distance, zero beats is not a meaningful floor, so the axis hugs
    // the data — the differences worth seeing here are small.
    private var beatsDomain: ClosedRange<Double> {
        let values = trend.points.map(\.beats) + [trend.fittedStart, trend.fittedEnd].compactMap { $0 }
        guard let lowest = values.min(), let highest = values.max() else { return 0...1 }
        guard highest > lowest else { return (lowest * 0.95)...(highest * 1.05) }
        let padding = (highest - lowest) * 0.15
        return (lowest - padding)...(highest + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Effort Trend")
                        .font(.headline)
                    Spacer()
                    Text(scope.menuLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Heartbeats spent per \(unit.distanceLabel) on each run. Lower means the same ground cost you less.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            metricRow
                .frame(height: 52, alignment: .top)
                .animation(.easeOut(duration: 0.12), value: selectedPointID)

            chart
                .frame(height: 168)

            if selectedPoint == nil, trend.hasData {
                VStack(alignment: .leading, spacing: 6) {
                    TrendChartLegend(showsTrendLine: trend.hasTrendLine)
                    if trend.runsWithoutHeartRate > 0 {
                        Text(omittedRunsText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("run-history-effort-trend")
        .sensoryFeedback(trigger: selectedPointID) { _, new in
            new != nil ? .selection : nil
        }
        .onChange(of: trend.points) { _, _ in selectedPointID = nil }
    }

    private var omittedRunsText: String {
        let count = trend.runsWithoutHeartRate
        return "\(count) \(count == 1 ? "run" : "runs") in this range had no heart rate recorded."
    }

    @ViewBuilder
    private var metricRow: some View {
        if let selectedPoint {
            scrubRow(for: selectedPoint)
        } else {
            idleRow
        }
    }

    private var idleRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if trend.hasData {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(trend.averageBeatsText)
                            .font(.title)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                        Text(unit.effortLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Average · \(trend.runCount) \(trend.runCount == 1 ? "run" : "runs")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text("—")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if trend.hasData {
                TrendVerdictBadge(verdict: .effort(trend))
            }
        }
    }

    private func scrubRow(for point: RunEffortPoint) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: RunHistorySymbols.effort)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(point.beatsText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                    Text(unit.effortLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Label("\(point.paceText) \(unit.paceLabel)", systemImage: RunHistorySymbols.pace)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: RunHistorySymbols.heartRate)
                        .font(.caption)
                        .foregroundStyle(.pink)
                    Text("\(point.heartRate)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                }
                Text(point.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        Chart {
            ForEach(trend.points) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Beats", point.beats)
                )
                .foregroundStyle(Color.green.opacity(0.4))
                .symbolSize(30)
            }

            if let fittedStart = trend.fittedStart, let fittedEnd = trend.fittedEnd,
               let first = trend.points.first, let last = trend.points.last {
                ForEach([(first.date, fittedStart), (last.date, fittedEnd)], id: \.0) { end in
                    LineMark(
                        x: .value("Date", end.0),
                        y: .value("Beats", end.1),
                        series: .value("Series", "Trend")
                    )
                }
                .foregroundStyle(Color.green)
                .lineStyle(.init(lineWidth: 2.5, lineCap: .round))
            }

            if let selectedPoint {
                RuleMark(x: .value("Selected date", selectedPoint.date))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(.init(lineWidth: 1))

                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value("Beats", selectedPoint.beats)
                )
                .foregroundStyle(Color(.systemBackground))
                .symbolSize(70)

                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value("Beats", selectedPoint.beats)
                )
                .foregroundStyle(Color.green)
                .symbolSize(34)
            }
        }
        .chartYScale(domain: beatsDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
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
                onScrub: { date in
                    guard let nearest = trend.points.nearest(to: date, by: \.date),
                          nearest.id != selectedPointID else { return }
                    selectedPointID = nearest.id
                },
                onEnd: { selectedPointID = nil }
            )
        }
        .overlay {
            if trend.points.isEmpty {
                ContentUnavailableView(
                    "No heart rate data",
                    systemImage: "bolt.heart",
                    description: Text("Effort needs runs recorded with heart rate, which usually means an Apple Watch.")
                )
                .background(Color(.systemBackground))
            }
        }
        .accessibilityLabel("Heartbeats per \(unit.distanceLabel), \(trend.runCount) runs")
        .accessibilityIdentifier("run-history-effort-plot")
    }
}
