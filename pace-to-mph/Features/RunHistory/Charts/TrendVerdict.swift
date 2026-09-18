import SwiftUI

/// Plain-language read on a trend line's direction. Stays muted for "steady"
/// and "building" so the colored verdicts carry the signal.
struct TrendVerdictBadge: View {
    let verdict: TrendVerdict

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: verdict.symbol)
                    .imageScale(.small)
                Text(verdict.word)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(verdict.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(verdict.tint.opacity(0.15)))

            if let detail = verdict.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(verdict.accessibilityText)
    }
}

struct TrendVerdict {
    let symbol: String
    let word: String
    let tint: Color
    let detail: String?
    let accessibilityText: String

    private static let muted = Color(.secondaryLabel)
    private static let building = TrendVerdict(
        symbol: "chart.dots.scatter",
        word: "Building",
        tint: muted,
        detail: "Need 5+ runs",
        accessibilityText: "Building, need at least 5 runs to show a trend"
    )

    static func speed(_ trend: RunSpeedTrend, unit: SpeedUnit) -> TrendVerdict {
        let change = "\(trend.changeMagnitudeText) \(unit.speedLabel)"
        switch trend.direction {
        case .faster:
            return TrendVerdict(symbol: "arrow.up.right", word: "Faster", tint: .green, detail: "+\(change)", accessibilityText: "Trending faster, up \(change)")
        case .slower:
            return TrendVerdict(symbol: "arrow.down.right", word: "Slower", tint: .orange, detail: "−\(change)", accessibilityText: "Trending slower, down \(change)")
        case .steady:
            return TrendVerdict(symbol: "arrow.left.and.right", word: "Steady", tint: muted, detail: "Little change", accessibilityText: "Holding steady")
        case .insufficient:
            return building
        }
    }

    static func runLength(_ trend: RunLengthTrend) -> TrendVerdict {
        let change = "\(trend.changeMagnitudeText) \(trend.unit.distanceLabel)"
        let spokenChange = "\(trend.changeMagnitudeText) \(trend.unit == .mph ? "miles" : "kilometers")"
        switch trend.direction {
        case .longer:
            return TrendVerdict(symbol: "arrow.up.right", word: "Longer", tint: .green, detail: "+\(change)", accessibilityText: "Runs trending longer, up \(spokenChange)")
        case .shorter:
            return TrendVerdict(symbol: "arrow.down.right", word: "Shorter", tint: .orange, detail: "−\(change)", accessibilityText: "Runs trending shorter, down \(spokenChange)")
        case .steady:
            return TrendVerdict(symbol: "arrow.left.and.right", word: "Steady", tint: muted, detail: "Little change", accessibilityText: "Run distance holding steady")
        case .unclear:
            return TrendVerdict(symbol: "arrow.up.arrow.down", word: "Mixed", tint: muted, detail: "No clear trend", accessibilityText: "Mixed, run distances vary too much to show a clear trend")
        case .insufficient:
            return building
        }
    }
}

struct TrendChartLegend: View {
    let showsTrendLine: Bool

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text("Each run")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if showsTrendLine {
                HStack(spacing: 5) {
                    Capsule()
                        .fill(Color.green)
                        .frame(width: 16, height: 3)
                    Text("Trend")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
