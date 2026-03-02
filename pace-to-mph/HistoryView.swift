import SwiftUI

struct HistoryView: View {
    @Bindable var history: ConversionHistory
    var favoritesStore: FavoritesStore
    @State private var showClearConfirmation = false

    var body: some View {
        Group {
            if history.records.isEmpty {
                ContentUnavailableView {
                    Label("No conversions yet", systemImage: "clock")
                } description: {
                    Text("Your recent conversions will appear here.")
                }
            } else {
                List {
                    ForEach(history.records) { record in
                        recordRow(record)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Recent Conversions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !history.records.isEmpty {
                    Button("Clear") {
                        showClearConfirmation = true
                    }
                }
            }
        }
        .alert("Clear History", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive) {
                history.clear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear all conversion history?")
        }
    }
    // MARK: - Row

    private func recordRow(_ record: ConversionRecord) -> some View {
        let isFav = favoritesStore.isFavorited(
            input: record.input,
            inputSuffix: record.inputSuffix,
            result: record.result,
            resultSuffix: record.resultSuffix
        )
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(record.input)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(record.inputSuffix)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("→")
                        .foregroundStyle(.secondary)
                    Text(record.result)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                    Text(record.resultSuffix)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(record.date, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(record.input) \(record.inputSuffix) equals \(record.result) \(record.resultSuffix)")
            .accessibilityValue("Converted \(record.date.formatted(.relative(presentation: .named)))")
            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    favoritesStore.toggle(
                        input: record.input,
                        inputSuffix: record.inputSuffix,
                        result: record.result,
                        resultSuffix: record.resultSuffix
                    )
                }
            } label: {
                Image(systemName: isFav ? "star.fill" : "star")
                    .font(.system(size: 16))
                    .foregroundStyle(isFav ? Color.yellow : Color.gray.opacity(0.4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFav ? "Remove from favorites" : "Add to favorites")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HistoryView(history: ConversionHistory(), favoritesStore: FavoritesStore())
    }
}
