import SwiftUI

// MARK: - Reference Tab

struct ReferenceTab: View {
    @State private var selectedUnit: SpeedUnit = .mph

    private let mphPaces: [PaceEntry] = {
        var result: [PaceEntry] = []
        for m in 5...12 {
            result.append(PaceEntry(min: m, sec: 0))
            if m < 12 { result.append(PaceEntry(min: m, sec: 30)) }
        }
        return result
    }()

    private let kphPaces: [PaceEntry] = {
        var result: [PaceEntry] = []
        for m in 3...8 {
            result.append(PaceEntry(min: m, sec: 0))
            if m < 8 { result.append(PaceEntry(min: m, sec: 30)) }
        }
        return result
    }()

    private var activePaces: [PaceEntry] {
        selectedUnit == .mph ? mphPaces : kphPaces
    }

    var body: some View {
        List {
            UnitToggle(selectedUnit: $selectedUnit)
                .listRowBackground(Color.clear)

            ForEach(activePaces) { pace in
                let speed = ConversionEngine.paceToSpeed(pace.paceMinutes)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pace.label)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .monospacedDigit()
                        Text(selectedUnit.paceLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ConversionEngine.formatSpeed(speed))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.green)
                        Text(selectedUnit.speedLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(pace.label) \(selectedUnit.paceLabel) equals \(ConversionEngine.formatSpeed(speed)) \(selectedUnit.speedLabel)")
            }
        }
        .navigationTitle("Reference")
    }
}
