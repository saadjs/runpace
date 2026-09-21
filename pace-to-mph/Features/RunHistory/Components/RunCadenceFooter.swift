import SwiftUI

/// Run frequency stated in plain words under the totals — the "how often",
/// which totals on their own never answer. Draws nothing when the window is
/// too short for an average to differ from the total.
struct RunCadenceFooter: View {
    let cadence: RunCadence

    var body: some View {
        if let averageText = cadence.averageText {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "repeat")
                        .imageScale(.small)
                        .foregroundStyle(.green)
                    Text(averageText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(cadence.accessibilityText ?? averageText)
        }
    }
}
