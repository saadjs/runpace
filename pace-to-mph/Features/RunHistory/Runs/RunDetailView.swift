import SwiftUI

/// Everything recorded for a single run. The list row has to stay scannable,
/// so it shows four numbers; this is where the rest of what Health gave us
/// lives — heart rate, elevation, effort, and where the run came from.
struct RunDetailView: View {
    let run: RunWorkout
    let unit: SpeedUnit
    let prBadges: [RunPRBadge]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    headlineCard
                    metricTiles
                    if let effortText {
                        effortCard(effortText)
                    }
                    sourceCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(Text(run.startDate, format: .dateTime.month(.abbreviated).day().year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .accessibilityIdentifier("run-history-run-detail")
        }
        .tint(.green)
    }

    // MARK: - Cards

    private var headlineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(run.startDate, format: .dateTime.weekday(.wide).hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(RunHistoryFormatters.decimal(run.distance(in: unit), fractionDigits: 2))
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit.distanceLabel)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if prBadges.isEmpty == false {
                HStack(spacing: 6) {
                    ForEach(prBadges) { badge in
                        Label(badge.title, systemImage: "rosette")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.green)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var metricTiles: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            RunSummaryMetric(
                value: paceText,
                label: "Pace",
                systemImage: RunHistorySymbols.pace,
                isAccent: true
            )
            RunSummaryMetric(
                value: RunHistoryFormatters.decimal(run.averageSpeed(in: unit), fractionDigits: 2),
                label: "Avg \(unit.speedLabel)",
                systemImage: RunHistorySymbols.speed
            )
            RunSummaryMetric(
                value: RunHistoryFormatters.duration(run.duration),
                label: "Time",
                systemImage: RunHistorySymbols.duration
            )
            if let heartRate = run.avgHeartRate {
                RunSummaryMetric(
                    value: "\(heartRate)",
                    label: "Avg BPM",
                    systemImage: RunHistorySymbols.heartRate
                )
            }
            if let elevation = run.elevationGain(in: unit) {
                RunSummaryMetric(
                    value: Int(elevation.rounded()).formatted(),
                    label: "Climb \(unit.elevationLabel)",
                    systemImage: RunHistorySymbols.elevation
                )
            }
        }
    }

    private func effortCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: RunHistorySymbols.effort)
                    .imageScale(.small)
                    .foregroundStyle(.pink)
                Text("Effort")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(text)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .monospacedDigit()
            }
            Text("Heartbeats spent per \(unit.distanceLabel). Lower is more efficient — the same pace at a calmer heart rate.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var sourceCard: some View {
        HStack(spacing: 6) {
            // Everything here arrives through Apple Health, whatever recorded
            // it, so the glyph names the source of the data rather than
            // guessing at a device.
            Image(systemName: "heart.text.square")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            Text("Recorded by \(run.source)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    // MARK: - Text

    private var paceText: String {
        guard let pace = run.paceMinutes(in: unit),
              let formatted = ConversionEngine.formatPace(pace) else { return "—" }
        return formatted
    }

    private var effortText: String? {
        guard let beats = run.beatsPerDistanceUnit(in: unit) else { return nil }
        return "\(Int(beats.rounded()).formatted()) \(unit.effortLabel)"
    }
}
