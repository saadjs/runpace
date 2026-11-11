import SwiftUI

struct RunHistoryRow: View {
    let run: RunWorkout
    let unit: SpeedUnit
    let prBadges: [RunPRBadge]

    @State private var showsDetail = false

    private var speedText: String {
        let value = unit == .mph ? run.averageSpeedMph : run.averageSpeedKph
        return String(format: "%.2f", value)
    }

    private var paceText: String {
        let pace = unit == .mph ? run.paceMinutesPerMile : run.paceMinutesPerKilometer
        guard let pace, let formatted = ConversionEngine.formatPace(pace) else { return "--" }
        return formatted
    }

    private var distanceText: String {
        let value = unit == .mph ? run.distanceMiles : run.distanceKilometers
        let label = unit == .mph ? "mi" : "km"
        return String(format: "%.2f %@", value, label)
    }

    private var durationText: String {
        RunHistoryFormatters.duration(run.duration)
    }

    private var elevationText: String? {
        guard let gain = run.elevationGain(in: unit) else { return nil }
        return "\(Int(gain.rounded()).formatted()) \(unit.elevationLabel)"
    }

    private func headerLine(showsBadges: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(spacing: 8) {
                Text(run.startDate, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .fixedSize()
                if showsBadges {
                    badgeCapsules
                }
            }

            Spacer(minLength: 12)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(speedText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(unit.speedLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var badgeCapsules: some View {
        ForEach(prBadges) { badge in
            PRBadgeCapsule(badge: badge)
        }
    }

    @ViewBuilder
    private func metricItems(font: Font, showsElevation: Bool) -> some View {
        Label(distanceText, systemImage: RunHistorySymbols.distance)
            .font(font)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .fixedSize()

        Label("\(paceText) \(unit.paceLabel)", systemImage: RunHistorySymbols.pace)
            .font(font)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .fixedSize()

        if let heartRate = run.avgHeartRate {
            HStack(spacing: 3) {
                Image(systemName: RunHistorySymbols.heartRate)
                    .imageScale(.small)
                    .foregroundStyle(.pink)
                Text("\(heartRate)")
                    .font(font)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Average heart rate \(heartRate) beats per minute")
        }

        if showsElevation, let elevationText {
            HStack(spacing: 3) {
                Image(systemName: RunHistorySymbols.elevation)
                    .imageScale(.small)
                Text(elevationText)
                    .font(font)
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Elevation gain \(elevationText)")
        }
    }

    private func metricsLine(font: Font, showsElevation: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            metricItems(font: font, showsElevation: showsElevation)

            Label(durationText, systemImage: RunHistorySymbols.duration)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// Last resort for the widest text sizes, where even the smallest font on
    /// one line runs off the row. Wrapping keeps every metric readable instead
    /// of letting the line overflow the card.
    private var wrappedMetricsLine: some View {
        FlowLayout(spacing: 10) {
            metricItems(font: .caption, showsElevation: true)

            Label(durationText, systemImage: RunHistorySymbols.duration)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        Button {
            showsDetail = true
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the full detail for this run")
        .sheet(isPresented: $showsDetail) {
            RunDetailView(run: run, unit: unit, prBadges: prBadges)
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if prBadges.isEmpty {
                headerLine(showsBadges: false)
            } else {
                // A long run can hold several records at once; when they don't
                // fit beside the date they move to their own wrapping line.
                ViewThatFits(in: .horizontal) {
                    headerLine(showsBadges: true)
                    VStack(alignment: .leading, spacing: 6) {
                        headerLine(showsBadges: false)
                        FlowLayout(spacing: 6) {
                            badgeCapsules
                        }
                    }
                }
            }

            // Shrink the metrics font rather than truncating values on narrow
            // rows; drop elevation before shrinking further, and wrap only when
            // nothing on one line fits.
            ViewThatFits(in: .horizontal) {
                metricsLine(font: .subheadline, showsElevation: true)
                metricsLine(font: .footnote, showsElevation: true)
                metricsLine(font: .caption, showsElevation: true)
                metricsLine(font: .caption, showsElevation: false)
                wrappedMetricsLine
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(.rect)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
                .padding(.leading, 16)
        }
    }
}

private struct PRBadgeCapsule: View {
    let badge: RunPRBadge

    var body: some View {
        Label(badge.title, systemImage: "rosette")
            .labelStyle(.titleAndIcon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.green)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.green.opacity(0.15))
            )
            .accessibilityLabel(badge.accessibilityName)
    }
}

/// Places subviews left to right, wrapping onto a new line when the row is full.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = frames(for: subviews, maxWidth: proposal.width ?? .infinity)
        let width = frames.map(\.maxX).max() ?? 0
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = frames(for: subviews, maxWidth: bounds.width)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func frames(for subviews: Subviews, maxWidth: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if origin.x > 0, origin.x + size.width > maxWidth {
                origin = CGPoint(x: 0, y: origin.y + rowHeight + spacing)
                rowHeight = 0
            }
            frames.append(CGRect(origin: origin, size: size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return frames
    }
}
