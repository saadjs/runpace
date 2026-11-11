import SwiftUI

/// One tile in the Run History summary: a quiet label with its symbol on top,
/// the number underneath. Each tile carries its own glass surface, so the four
/// read as separate pieces of information rather than columns of a table.
struct RunSummaryMetric: View {
    let value: String
    let label: String
    var systemImage: String? = nil
    var isAccent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.small)
                }
                Text(label)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(isAccent ? Color.green : .primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}
