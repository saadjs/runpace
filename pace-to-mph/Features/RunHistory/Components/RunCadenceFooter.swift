import SwiftUI

/// Run frequency stated in plain words under the totals — the "how often",
/// which totals on their own never answer. Draws nothing when the window is
/// too short for an average to differ from the total.
struct RunCadenceFooter: View {
    let cadence: RunCadence
    /// Inside a card the footer needs a rule to divide it from the content
    /// above. Standing on its own surface it does not.
    var showsSeparator = true

    var body: some View {
        if let averageText = cadence.averageText {
            VStack(spacing: 0) {
                if showsSeparator {
                    Divider()
                }
                HStack(spacing: 6) {
                    Image(systemName: "repeat")
                        .imageScale(.small)
                        .foregroundStyle(.green)
                    Text(averageText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        // Wraps rather than truncating at the largest text
                        // sizes. No minimumScaleFactor: with lines unlimited
                        // the text wraps before it would ever scale, so the
                        // floor never engaged.
                        .multilineTextAlignment(.center)
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
