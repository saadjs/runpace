import Charts
import SwiftUI

/// Hero of the Trends tab: plots every run's average speed as dots with a
/// best-fit trend line, plus a plain-language verdict, so "am I getting faster?"
/// reads at a glance. Scrub the chart to inspect any single run.
struct SpeedTrendCard: View {
    let trend: RunSpeedTrend
    let overallRunCount: Int
    let availableTargets: [RunRecordTarget]
    @Binding var selectedDistance: RunRecordTarget?
    @Binding var selectedPoint: RunChartPoint?
    let scope: RunTrendScope
    let unit: SpeedUnit

    private var speedDomain: ClosedRange<Double> {
        var values = trend.points.map(\.speed)
        if let start = trend.trendStart?.speed { values.append(start) }
        if let end = trend.trendEnd?.speed { values.append(end) }
        guard let minSpeed = values.min(), let maxSpeed = values.max() else {
            return 0...1
        }
        let spread = maxSpeed - minSpeed
        let padding = max(spread * 0.3, 0.1)
        let lowerBound = max(0, minSpeed - padding)
        return lowerBound...(maxSpeed + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            metricRow
                .frame(height: 52, alignment: .top)
                .animation(.easeOut(duration: 0.12), value: selectedPoint?.id)

            chart
                .frame(height: 168)

            if selectedPoint == nil, trend.hasData {
                TrendChartLegend(showsTrendLine: trend.trendEnd != nil)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("run-history-speed-trend")
        .sensoryFeedback(trigger: selectedPoint?.id) { _, new in
            new != nil ? .selection : nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Speed Trend")
                    .font(.headline)
                Spacer()
                Text(scope.menuLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(descriptionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if availableTargets.isEmpty == false {
                Picker("Distance", selection: $selectedDistance) {
                    Text("ALL").tag(nil as RunRecordTarget?)
                    ForEach(availableTargets) { target in
                        Text(target.shortLabel).tag(Optional(target))
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Distance")
            }
            if let selectedDistance {
                Text("\(trend.runCount) of \(overallRunCount) runs included · \(selectedDistance.matchingRangeText(in: unit))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("run-history-speed-inclusion")
            }
        }
    }

    private var descriptionText: String {
        if let selectedDistance {
            return "Your \(selectedDistance.displayName) runs are trending based on comparable efforts only."
        }
        return "Overall average-speed trend across every run in this range."
    }

    @ViewBuilder
    private var metricRow: some View {
        if let point = selectedPoint {
            scrubRow(for: point)
        } else {
            idleRow
        }
    }

    private var idleRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if trend.hasData {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(trend.averageSpeedText)
                            .font(.title)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                        Text(unit.speedLabel)
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
                TrendVerdictBadge(verdict: .speed(trend, unit: unit))
            }
        }
    }

    private func scrubRow(for point: RunChartPoint) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: RunHistorySymbols.speed)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", point.speed))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                    Text(unit.speedLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Label("\(point.paceText) \(unit.paceLabel)", systemImage: RunHistorySymbols.pace)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    if let heartRate = point.avgHeartRate {
                        HStack(spacing: 3) {
                            Image(systemName: RunHistorySymbols.heartRate)
                                .imageScale(.small)
                                .foregroundStyle(.pink)
                            Text("\(heartRate)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Average heart rate \(heartRate) beats per minute")
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: RunHistorySymbols.distance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(point.distanceValueText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                    Text(unit == .mph ? "mi" : "km")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(point.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(trend.points) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value(unit.speedLabel, point.speed)
                )
                .foregroundStyle(Color.green.opacity(0.4))
                .symbolSize(30)
            }

            if let start = trend.trendStart, let end = trend.trendEnd {
                ForEach([start, end]) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(unit.speedLabel, point.speed)
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
                    y: .value(unit.speedLabel, selectedPoint.speed)
                )
                .foregroundStyle(Color(.systemBackground))
                .symbolSize(70)

                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value(unit.speedLabel, selectedPoint.speed)
                )
                .foregroundStyle(Color.green)
                .symbolSize(34)
            }
        }
        .chartYScale(domain: speedDomain)
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
                onScrub: selectNearestPoint(to:),
                onEnd: { selectedPoint = nil }
            )
        }
        .overlay {
            if trend.points.isEmpty {
                ContentUnavailableView(
                    "No runs in this range",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Try a longer time range to see your speed trend.")
                )
                .background(Color(.systemBackground))
            }
        }
    }

    private func selectNearestPoint(to date: Date) {
        guard let nearest = trend.points.nearest(to: date, by: \.date) else { return }

        if selectedPoint?.id != nearest.id {
            selectedPoint = nearest
        }
    }
}
