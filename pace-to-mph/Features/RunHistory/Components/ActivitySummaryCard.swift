import SwiftUI

struct ActivitySummaryCard: View {
    let summary: RunActivitySummary
    let scope: RunTrendScope

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Period Comparison")
                    .font(.headline)
                Spacer()
                Text(scope.menuLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 0) {
                metric(
                    value: "\(summary.runCount)",
                    label: summary.runCount == 1 ? "Run" : "Runs",
                    delta: runCountDeltaText,
                    systemImage: RunHistorySymbols.runs
                )

                Divider().frame(height: 56)

                metric(
                    value: summary.distanceText,
                    label: "Total \(summary.distanceUnitLabel)",
                    delta: distanceDeltaText,
                    systemImage: RunHistorySymbols.distance,
                    isAccent: true
                )

                Divider().frame(height: 56)

                metric(
                    value: summary.averagePaceText,
                    label: "Avg \(summary.unit.paceLabel)",
                    delta: paceDeltaText,
                    systemImage: RunHistorySymbols.pace
                )
            }

            // Negative insets let the divider run edge to edge inside the card.
            RunCadenceFooter(cadence: summary.cadence)
                .padding(.horizontal, -16)
                .padding(.bottom, -6)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("run-history-period-comparison")
    }

    private var runCountDeltaText: DeltaText? {
        guard let delta = summary.runCountDelta else { return nil }
        if delta == 0 { return DeltaText(text: "No change", isPositive: true, isNeutral: true) }
        let sign = delta > 0 ? "+" : ""
        return DeltaText(text: "\(sign)\(delta) vs prev", isPositive: delta >= 0, isNeutral: false)
    }

    private var distanceDeltaText: DeltaText? {
        guard let pct = summary.distanceDeltaPercent else { return nil }
        if abs(pct) < 0.005 { return DeltaText(text: "No change", isPositive: true, isNeutral: true) }
        return DeltaText(text: "\(RunHistoryFormatters.percent(pct)) vs prev", isPositive: pct >= 0, isNeutral: false)
    }

    private var paceDeltaText: DeltaText? {
        guard let pct = summary.paceImprovementPercent else { return nil }
        if abs(pct) < 0.005 { return DeltaText(text: "No change", isPositive: true, isNeutral: true) }
        return DeltaText(
            text: "\(RunHistoryFormatters.percent(pct)) vs prev",
            isPositive: pct >= 0,
            isNeutral: false
        )
    }

    private struct DeltaText {
        let text: String
        let isPositive: Bool
        let isNeutral: Bool
    }

    private func deltaColor(for delta: DeltaText) -> Color {
        if delta.isNeutral { return .secondary }
        return delta.isPositive ? .green : .red
    }

    private func metric(
        value: String,
        label: String,
        delta: DeltaText?,
        systemImage: String? = nil,
        isAccent: Bool = false
    ) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(isAccent ? Color.green : .primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

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

            if let delta {
                Text(delta.text)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(deltaColor(for: delta))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text(" ")
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}
