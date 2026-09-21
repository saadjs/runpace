import SwiftUI

/// Shown when no single distance has enough runs in scope to chart a trend —
/// distinct from "no runs at all" so the runner knows what unlocks it.
struct SpeedTrendEmptyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speed Trend")
                .font(.headline)
            ContentUnavailableView(
                "Not enough runs at one distance",
                systemImage: "chart.xyaxis.line",
                description: Text("Log at least 2 runs at the same distance (5K, 10K, and so on) to see how your speed is trending.")
            )
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("run-history-speed-trend-empty")
    }
}

struct PaceTrendEmptyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Average Pace Trend")
                .font(.headline)
            ContentUnavailableView(
                "Not enough runs at one distance",
                systemImage: RunHistorySymbols.pace,
                description: Text("Log at least 2 runs near the same named distance to compare pace.")
            )
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("run-history-pace-trend-empty")
    }
}
