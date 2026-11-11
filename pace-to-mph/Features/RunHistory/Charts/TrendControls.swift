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

/// A scrolling row of chips rather than a segmented control: segments divide
/// the width evenly between them, so each new metric squeezes every label.
/// Chips size to their own text and scroll, which holds at any count and at
/// any Dynamic Type size.
struct TrendMetricPicker: View {
    @Binding var selection: RunTrendMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Explore Trends")
                .font(.headline)
                .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(RunTrendMetric.allCases) { metric in
                        chip(for: metric)
                    }
                }
                .padding(.horizontal, 16)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            // Keeps the selected metric in view when it is chosen off-screen
            // or restored from a previous session.
            .scrollPosition(id: scrolledMetric, anchor: .center)
            .accessibilityIdentifier("run-history-trend-metric")
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Trend metric")
        }
        .padding(.vertical, 16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    private var scrolledMetric: Binding<RunTrendMetric?> {
        .init(get: { selection }, set: { _ in })
    }

    private func chip(for metric: RunTrendMetric) -> some View {
        let isSelected = metric == selection
        return Button {
            selection = metric
        } label: {
            Label(metric.title, systemImage: metric.systemImage)
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.green : Color.primary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background {
                    Capsule()
                        .fill(isSelected ? Color.green.opacity(0.15) : Color(.tertiarySystemFill))
                }
        }
        .buttonStyle(.plain)
        .id(metric)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
