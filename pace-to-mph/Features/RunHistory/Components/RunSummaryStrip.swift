import SwiftUI

struct RunSummaryStrip: View {
    let summary: RunHistorySummary
    let cadence: RunCadence
    let unit: SpeedUnit

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                RunSummaryMetric(
                    value: summary.distanceText,
                    label: unit == .mph ? "Total mi" : "Total km",
                    systemImage: RunHistorySymbols.distance
                )

                Divider().frame(height: 44)

                RunSummaryMetric(
                    value: summary.durationText,
                    label: "Total time",
                    systemImage: RunHistorySymbols.duration
                )

                Divider().frame(height: 44)

                RunSummaryMetric(
                    value: summary.averageSpeedText,
                    label: "Avg \(unit.speedLabel)",
                    systemImage: RunHistorySymbols.speed,
                    isAccent: true
                )
            }
            .padding(.vertical, 16)

            RunCadenceFooter(cadence: cadence)
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}
