import SwiftUI

struct ReferenceView: View {
    @State private var settings = UnitSettings.shared
    private var selectedUnit: SpeedUnit { settings.unit }

    private struct PaceEntry: Identifiable {
        let min: Int
        let sec: Int
        var id: Int { min * 60 + sec }
        var paceMinutes: Double { Double(min) + Double(sec) / 60.0 }
        var label: String { "\(min):\(String(format: "%02d", sec))" }
    }

    // Round paces per mile: 5:00–12:00 in 30s steps
    private let mphPaces: [PaceEntry] = {
        var result: [PaceEntry] = []
        for m in 5...12 {
            result.append(PaceEntry(min: m, sec: 0))
            if m < 12 { result.append(PaceEntry(min: m, sec: 30)) }
        }
        return result
    }()

    // Round paces per km: 3:00–8:00 in 30s steps
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
        VStack(spacing: 0) {
            List {
                ForEach(activePaces) { pace in
                    let speed = ConversionEngine.paceToSpeed(pace.paceMinutes)

                    HStack {
                        Text(pace.label)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        Text(selectedUnit.paceLabel)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(ConversionEngine.formatSpeed(speed))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.green)

                        Text(selectedUnit.speedLabel)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(pace.label) \(selectedUnit.paceLabel) equals \(ConversionEngine.formatSpeed(speed)) \(selectedUnit.speedLabel)")
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Reference")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ReferenceView()
    }
}
