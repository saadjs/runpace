import SwiftUI

extension RunHistoryContent {
    @ViewBuilder
    var trendsBody: some View {
        if records.isEmpty && activitySummary.runCount == 0 {
            trendsEmptyView
        } else {
            Group {
                TrendScopeMenu(
                    scope: $selectedTrendScope,
                    earliestRunDate: runs.map(\.startDate).min()
                )
                ActivitySummaryCard(summary: activitySummary, scope: selectedTrendScope)
                moreInsightsSection
                TrendMetricPicker(selection: $selectedTrendMetric)
                selectedTrendChart
            }
            .tint(.green)
        }
    }

    @ViewBuilder
    var selectedTrendChart: some View {
        switch selectedTrendMetric {
        case .speed:
            SpeedTrendCard(
                trend: selectedSpeedTrend,
                overallRunCount: overallSpeedTrend.runCount,
                availableTargets: availableTrendTargets,
                selectedDistance: Binding(
                    get: { resolvedSpeedTrendDistance },
                    set: { selectedTrendDistance = $0 }
                ),
                selectedPoint: $selectedChartPoint,
                scope: selectedTrendScope,
                unit: unit
            )
        case .pace:
            if let resolved = resolvedTrendDistance {
                PaceTrendCard(
                    points: paceTrendPoints,
                    availableTargets: availableTrendTargets,
                    selectedDistance: Binding(
                        get: { resolved },
                        set: { selectedTrendDistance = $0 }
                    ),
                    scope: selectedTrendScope,
                    unit: unit
                )
            } else {
                PaceTrendEmptyCard()
            }
        case .volume:
            WeeklyVolumeCard(
                bars: volumeBars,
                cadence: activitySummary.cadence,
                scope: selectedTrendScope,
                unit: unit
            )
        case .distance:
            RunLengthTrendCard(trend: runLengthTrend, scope: selectedTrendScope, unit: unit)
        }
    }

    var moreInsightsSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.snappy) {
                    showsMoreInsights.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Label("Highlights & Personal Bests", systemImage: "sparkles")
                        .font(.headline)
                    Spacer(minLength: 8)
                    if activitySummary.prHighlightCount > 0 {
                        Text("\(activitySummary.prHighlightCount) PB")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.12), in: .capsule)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showsMoreInsights ? 180 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(16)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            .accessibilityIdentifier("run-history-more-insights")
            .accessibilityLabel("Highlights & Personal Bests")
            .accessibilityValue(showsMoreInsights ? "Expanded" : "Collapsed")

            if showsMoreInsights {
                TrainingHighlightsCard(summary: activitySummary, scope: selectedTrendScope)
                PersonalBestsGrid(records: records, runs: runs, unit: unit)
            }
        }
    }

    var trendsEmptyView: some View {
        ContentUnavailableView(
            "Not enough data",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Run a few more times to start seeing your trends.")
        )
        .font(.caption)
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

}
