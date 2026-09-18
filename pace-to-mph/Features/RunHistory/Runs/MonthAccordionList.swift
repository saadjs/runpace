import SwiftUI

// MARK: - Year grouping

/// Summary-first month cards keep a full year scannable while individual runs
/// remain one tap away.
struct MonthAccordionList: View {
    let months: [RunHistoryMonth]
    let unit: SpeedUnit
    let prBadgesByRunID: [UUID: [RunPRBadge]]
    @Binding var expandedMonthIDs: Set<String>

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(months) { month in
                let isExpanded = expandedMonthIDs.contains(month.id)
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            if isExpanded {
                                expandedMonthIDs.remove(month.id)
                            } else {
                                expandedMonthIDs.insert(month.id)
                            }
                        }
                    } label: {
                        MonthHeader(month: month, isExpanded: isExpanded)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("run-history-month-card-\(month.id)")
                    .accessibilityLabel(month.accessibilitySummary)
                    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                    .accessibilityHint(isExpanded ? "Collapse month" : "Expand month")

                    if isExpanded {
                        ForEach(month.runs) { run in
                            RunHistoryRow(
                                run: run,
                                unit: unit,
                                prBadges: prBadgesByRunID[run.id] ?? []
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            }
        }
    }
}

private struct MonthHeader: View {
    let month: RunHistoryMonth
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)

                Text(month.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(month.runCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Label(month.distanceText, systemImage: RunHistorySymbols.distance)
                Text("·")
                Label("Avg \(month.averageSpeedText)", systemImage: RunHistorySymbols.speed)
                Spacer(minLength: 0)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            .padding(.leading, 22)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
