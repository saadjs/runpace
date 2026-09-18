import SwiftUI

// MARK: - Race Calculator Tab

struct RaceCalcTab: View {
    @State private var selectedUnit: SpeedUnit = .mph
    @State private var selectedDistance: RaceCalculator.Distance = .fiveK
    @State private var paceMinutes: Int = 8
    @State private var paceSeconds: Int = 0

    private var selectedUnitBinding: Binding<SpeedUnit> {
        makeUnitBinding(unit: $selectedUnit, paceMinutes: $paceMinutes, paceSeconds: $paceSeconds)
    }

    private var paceValue: Double {
        Double(paceMinutes) + Double(paceSeconds) / 60.0
    }

    private var finishTimeSeconds: Int {
        guard paceValue > 0, let distance = selectedDistance.distance(unit: selectedUnit) else { return 0 }
        return RaceCalculator.finishTime(paceMinutes: paceValue, distanceInUnits: distance)
    }

    var body: some View {
        raceContent
        .navigationTitle("Race Calc")
    }

    @ViewBuilder
    private var raceContent: some View {
        if #available(watchOS 26.0, *) {
            GlassEffectContainer {
                raceScrollView
            }
        } else {
            raceScrollView
        }
    }

    private var raceScrollView: some View {
        ScrollView {
            VStack(spacing: 10) {
                UnitToggle(selectedUnit: selectedUnitBinding)

                DistanceSelector(selected: $selectedDistance)

                PaceInputRow(
                    paceMinutes: $paceMinutes,
                    paceSeconds: $paceSeconds,
                    paceLabel: selectedUnit.paceLabel
                )

                Divider()

                // Finish time result
                VStack(spacing: 4) {
                    Text("Finish Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(RaceCalculator.formatDuration(finishTimeSeconds))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .watchGlassCard()
            }
            .padding(.horizontal)
        }
    }
}
