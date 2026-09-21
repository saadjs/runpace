import SwiftUI

struct RunHistorySyncFooter: View {
    let lastSyncedAt: Date?
    let isLoading: Bool
    let onSync: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Spacer()

            if let lastSyncedAt {
                Text("Last synced \(lastSyncedAt.formatted(date: .abbreviated, time: .shortened))")
                    .accessibilityIdentifier("run-history-last-synced")
            } else {
                Text("Not synced yet")
            }

            if isLoading {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Button(action: onSync) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sync now")
                .accessibilityIdentifier("run-history-sync-now")
            }

            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.vertical, 7)
    }
}
