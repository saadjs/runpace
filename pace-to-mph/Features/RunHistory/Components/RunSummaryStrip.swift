import SwiftUI

struct RunSummaryStrip: View {
    let summary: RunHistorySummary
    let cadence: RunCadence
    let unit: SpeedUnit

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let tileSpacing: CGFloat = 10

    var body: some View {
        VStack(spacing: tileSpacing) {
            // A small, fixed cluster of glass that never animates its height is
            // exactly what a container is for — unlike the scroll of accordion
            // cards around it, which is deliberately left uncontained.
            GlassEffectContainer(spacing: tileSpacing) {
                if dynamicTypeSize.isAccessibilitySize {
                    stackedTiles
                } else {
                    tileGrid
                }
            }

            RunCadenceFooter(cadence: cadence, showsSeparator: false)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
    }

    /// Two by two. Each tile gets about half the width, which is room enough
    /// for every label at full size — no scaling, no truncation.
    private var tileGrid: some View {
        Grid(horizontalSpacing: tileSpacing, verticalSpacing: tileSpacing) {
            GridRow {
                runCountTile
                distanceTile
            }

            GridRow {
                durationTile
                averageSpeedTile
            }
        }
    }

    /// At accessibility text sizes half a tile is too narrow, so they go one
    /// per row and each number keeps its full size.
    private var stackedTiles: some View {
        VStack(spacing: tileSpacing) {
            runCountTile
            distanceTile
            durationTile
            averageSpeedTile
        }
    }

    private var runCountTile: some View {
        RunSummaryMetric(
            value: "\(summary.runCount)",
            label: "Runs",
            systemImage: RunHistorySymbols.runs
        )
    }

    private var distanceTile: some View {
        RunSummaryMetric(
            value: summary.distanceText,
            label: "Distance",
            systemImage: RunHistorySymbols.distance
        )
        // The tile shows a bare number now that the label no longer carries the
        // unit, so spell the unit out for VoiceOver.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Distance: \(summary.distanceText) \(unit == .mph ? "miles" : "kilometers")")
    }

    private var durationTile: some View {
        RunSummaryMetric(
            value: summary.durationText,
            label: "Time",
            systemImage: RunHistorySymbols.duration
        )
    }

    private var averageSpeedTile: some View {
        RunSummaryMetric(
            value: summary.averageSpeedText,
            label: "Avg \(unit.speedLabel)",
            systemImage: RunHistorySymbols.speed,
            isAccent: true
        )
    }
}
