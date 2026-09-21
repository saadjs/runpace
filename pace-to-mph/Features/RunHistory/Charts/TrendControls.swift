import SwiftUI

struct TrendScopeMenu: View {
    @Binding var scope: RunTrendScope
    let earliestRunDate: Date?

    private var dateRangeText: String? {
        scope.dateRangeText(earliestRunDate: earliestRunDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Label("Showing", systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)

                Spacer()

                Menu {
                    Picker("Scope", selection: $scope) {
                        ForEach(RunTrendScope.allCases) { value in
                            Text(value.menuLabel).tag(value)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(scope.menuLabel)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.tint)
                }
                .accessibilityLabel("Trend scope")
                .accessibilityValue(
                    [scope.menuLabel, dateRangeText].compactMap { $0 }.joined(separator: ", ")
                )
            }

            if let dateRangeText {
                Text(dateRangeText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("run-history-trend-date-range")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
}

struct TrendMetricPicker: View {
    @Binding var selection: RunTrendMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Explore Trends")
                .font(.headline)

            Picker("Trend metric", selection: $selection) {
                ForEach(RunTrendMetric.allCases) { metric in
                    Label(metric.title, systemImage: metric.systemImage)
                        .tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("run-history-trend-metric")
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}
