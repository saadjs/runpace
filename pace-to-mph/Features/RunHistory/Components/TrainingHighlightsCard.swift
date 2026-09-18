import SwiftUI

struct TrainingHighlightsCard: View {
    let summary: RunActivitySummary
    let scope: RunTrendScope

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Training Highlights")
                    .font(.headline)
                Spacer()
                Text(scope.menuLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                highlight(
                    value: summary.longestRunText,
                    label: "Longest run",
                    systemImage: RunHistorySymbols.distance,
                    tint: .green
                )
                highlight(
                    value: summary.elevationGainText,
                    label: summary.elevationGainLabel,
                    systemImage: "mountain.2",
                    tint: .orange
                )
                highlight(
                    value: summary.consistencyText,
                    label: "Active weeks",
                    systemImage: "calendar.badge.checkmark",
                    tint: .blue
                )
                highlight(
                    value: "\(summary.prHighlightCount)",
                    label: summary.prHighlightCount == 1 ? "PR highlight" : "PR highlights",
                    systemImage: "rosette",
                    tint: .green
                )
            }

            if summary.prHighlightCount > 0 {
                Label(summary.prHighlightNames, systemImage: "rosette")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Personal best highlights: \(summary.prHighlightAccessibilityNames)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("run-history-training-highlights")
    }

    private func highlight(
        value: String,
        label: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.45), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
