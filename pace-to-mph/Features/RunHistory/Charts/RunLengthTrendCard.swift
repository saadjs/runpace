import Charts
import SwiftUI

/// Plots how far every run in scope went with a best-fit line, so "are my
/// runs getting longer?" reads at a glance. Scrub to inspect a single run.
struct RunLengthTrendCard: View {
    let trend: RunLengthTrend
    let scope: RunTrendScope
    let unit: SpeedUnit

    @State private var selectedPointID: String?

    private var selectedPoint: RunLengthPoint? {
        guard let selectedPointID else { return nil }
        return trend.points.first { $0.id == selectedPointID }
    }

    // Distance starts at zero so a 3-mile run reads as a third of a 9-mile one.
    private var distanceDomain: ClosedRange<Double> {
        let values = trend.points.map(\.distance) + [trend.fittedStart, trend.fittedEnd].compactMap { $0 }
        guard let highest = values.max(), highest > 0 else { return 0...1 }
        return min(0, values.min() ?? 0)...(highest * 1.15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Distance Trend")
                        .font(.headline)
                    Spacer()
                    Text(scope.menuLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("How far each run went in this range, with a best-fit line.")
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
                TrendChartLegend(showsTrendLine: trend.hasTrendLine)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("run-history-distance-trend")
        .sensoryFeedback(trigger: selectedPointID) { _, new in
            new != nil ? .selection : nil
        }
        .onChange(of: trend.points) { _, _ in selectedPointID = nil }
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
                        Text(trend.averageDistanceText)
                            .font(.title)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                        Text(unit.distanceLabel)
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
                TrendVerdictBadge(verdict: .runLength(trend))
            }
        }
    }

    private func scrubRow(for point: RunLengthPoint) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: RunHistorySymbols.distance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(point.distanceValueText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                    Text(unit.distanceLabel)
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
                    Image(systemName: RunHistorySymbols.duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(point.duration > 0 ? RunHistoryFormatters.duration(point.duration) : "--")
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
                    y: .value("Distance", point.distance)
                )
                .foregroundStyle(Color.green.opacity(0.4))
                .symbolSize(30)
            }

            if let fittedStart = trend.fittedStart, let fittedEnd = trend.fittedEnd,
               let first = trend.points.first, let last = trend.points.last {
                ForEach([(first.date, fittedStart), (last.date, fittedEnd)], id: \.0) { end in
                    LineMark(
                        x: .value("Date", end.0),
                        y: .value("Distance", end.1),
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
                    y: .value("Distance", selectedPoint.distance)
                )
                .foregroundStyle(Color(.systemBackground))
                .symbolSize(70)

                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value("Distance", selectedPoint.distance)
                )
                .foregroundStyle(Color.green)
                .symbolSize(34)
            }
        }
        .chartYScale(domain: distanceDomain)
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
                    "No runs in this range",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Try a longer time range to see your distance trend.")
                )
                .background(Color(.systemBackground))
            }
        }
        .accessibilityLabel("Distance per run, \(trend.runCount) runs")
        .accessibilityIdentifier("run-history-distance-plot")
    }
}
