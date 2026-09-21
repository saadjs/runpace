import Charts
import SwiftUI

struct PaceTrendCard: View {
    let points: [RunPaceTrendPoint]
    let availableTargets: [RunRecordTarget]
    @Binding var selectedDistance: RunRecordTarget
    let scope: RunTrendScope
    let unit: SpeedUnit

    @State private var selectedDate: Date?

    private var selectedPoint: RunPaceTrendPoint? {
        guard let selectedDate else { return nil }
        return points.nearest(to: selectedDate, by: \.periodStart)
    }

    private var paceDomain: ClosedRange<Double> {
        guard let fastest = points.map(\.paceMinutes).min(),
              let slowest = points.map(\.paceMinutes).max() else { return 0...1 }
        let padding = max((slowest - fastest) * 0.25, 0.15)
        return max(0, fastest - padding)...(slowest + padding)
    }

    private var changeText: String? {
        guard let first = points.first, let last = points.last, points.count > 1 else { return nil }
        let seconds = Int((abs(last.paceMinutes - first.paceMinutes) * 60.0).rounded())
        if seconds < 2 { return "Holding steady" }
        return last.paceMinutes < first.paceMinutes
            ? "\(seconds)s faster"
            : "\(seconds)s slower"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Average Pace Trend")
                        .font(.headline)
                    Spacer()
                    Text(scope.bucketing == .weekly ? "By week" : "By month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Average \(unit.paceLabel) for your \(selectedDistance.displayName) runs only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if availableTargets.count > 1 {
                    Picker("Distance", selection: $selectedDistance) {
                        ForEach(availableTargets) { target in
                            Text(target.shortLabel).tag(target)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Pace distance")
                }
            }

            if points.isEmpty {
                ContentUnavailableView(
                    "No pace data",
                    systemImage: RunHistorySymbols.pace,
                    description: Text("Try a longer time range to chart your average pace.")
                )
                .frame(maxWidth: .infinity, minHeight: 130)
            } else {
                metricRow
                    .frame(height: 48, alignment: .top)
                    .animation(.easeOut(duration: 0.12), value: selectedPoint?.id)
                    .accessibilityIdentifier(
                        selectedPoint == nil ? "run-history-pace-summary" : "run-history-pace-selection"
                    )

                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Period", point.periodStart),
                            y: .value("Pace", point.paceMinutes)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.green)
                        .lineStyle(.init(lineWidth: 2.5, lineCap: .round))

                        PointMark(
                            x: .value("Period", point.periodStart),
                            y: .value("Pace", point.paceMinutes)
                        )
                        .foregroundStyle(Color.green.opacity(0.7))
                        .symbolSize(28)
                    }

                    if let selectedPoint {
                        RuleMark(x: .value("Selected period", selectedPoint.periodStart))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .lineStyle(.init(lineWidth: 1))

                        PointMark(
                            x: .value("Selected period", selectedPoint.periodStart),
                            y: .value("Selected pace", selectedPoint.paceMinutes)
                        )
                        .foregroundStyle(Color(.systemBackground))
                        .symbolSize(76)

                        PointMark(
                            x: .value("Selected period", selectedPoint.periodStart),
                            y: .value("Selected pace", selectedPoint.paceMinutes)
                        )
                        .foregroundStyle(Color.green)
                        .symbolSize(38)
                    }
                }
                .chartYScale(domain: paceDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let pace = value.as(Double.self) {
                                Text(ConversionEngine.formatPace(pace) ?? "—")
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    ChartScrubOverlay(
                        proxy: proxy,
                        onScrub: selectNearestPoint(to:),
                        onEnd: { selectedDate = nil }
                    )
                }
                .frame(height: 150)
                .accessibilityLabel("Average pace trend, \(points.count) periods")
                .accessibilityIdentifier("run-history-pace-plot")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("run-history-pace-trend")
        .sensoryFeedback(.selection, trigger: selectedPoint?.id)
        .onChange(of: points) { _, _ in selectedDate = nil }
    }

    private func selectNearestPoint(to date: Date) {
        guard let nearest = points.nearest(to: date, by: \.periodStart) else { return }

        if selectedPoint?.id != nearest.id {
            selectedDate = nearest.periodStart
        }
    }

    @ViewBuilder
    private var metricRow: some View {
        if let selectedPoint {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: RunHistorySymbols.pace)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(selectedPoint.paceText)
                            .font(.title2.weight(.semibold))
                            .fontDesign(.rounded)
                            .monospacedDigit()
                        Text(unit.paceLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Average pace · \(selectedPoint.runCount) \(selectedPoint.runCount == 1 ? "run" : "runs")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Label(distanceText(selectedPoint.distance), systemImage: RunHistorySymbols.distance)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text(periodTitle(for: selectedPoint.periodStart))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(periodTitle(for: selectedPoint.periodStart)), average pace \(selectedPoint.paceText) \(unit.paceLabel), \(selectedPoint.runCount) runs, \(distanceText(selectedPoint.distance))")
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(points.last?.paceText ?? "—")
                    .font(.title2.weight(.semibold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                Text(unit.paceLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let changeText {
                    Label(changeText, systemImage: paceTrendSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(paceTrendColor)
                }
            }
        }
    }

    private func distanceText(_ distance: Double) -> String {
        "\(String(format: "%.1f", distance)) \(unit == .mph ? "mi" : "km")"
    }

    private func periodTitle(for start: Date) -> String {
        if scope.bucketing == .monthly {
            return start.formatted(.dateTime.month(.abbreviated).year())
        }
        let end = RunHistoryStats.calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return RunHistoryFormatters.weekRange(start, end)
    }

    private var paceTrendSymbol: String {
        guard let first = points.first, let last = points.last else { return "minus" }
        if abs(last.paceMinutes - first.paceMinutes) < (2.0 / 60.0) { return "minus" }
        return last.paceMinutes < first.paceMinutes ? "arrow.down.right" : "arrow.up.right"
    }

    private var paceTrendColor: Color {
        guard let first = points.first, let last = points.last else { return .secondary }
        if abs(last.paceMinutes - first.paceMinutes) < (2.0 / 60.0) { return .secondary }
        return last.paceMinutes < first.paceMinutes ? .green : .orange
    }
}
