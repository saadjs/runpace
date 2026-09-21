import SwiftUI

// MARK: - Converter Tab

struct ConverterTab: View {
    @State private var selectedUnit: SpeedUnit = .mph
    @State private var paceMinutes: Int = 8
    @State private var paceSeconds: Int = 0

    private var selectedUnitBinding: Binding<SpeedUnit> {
        makeUnitBinding(unit: $selectedUnit, paceMinutes: $paceMinutes, paceSeconds: $paceSeconds)
    }

    private var paceValue: Double {
        Double(paceMinutes) + Double(paceSeconds) / 60.0
    }

    private var speed: Double {
        guard paceValue > 0 else { return 0 }
        return ConversionEngine.paceToSpeed(paceValue)
    }

    var body: some View {
        NavigationStack {
            converterContent
            .navigationTitle("Converter")
        }
    }

    @ViewBuilder
    private var converterContent: some View {
        if #available(watchOS 26.0, *) {
            GlassEffectContainer {
                converterScrollView
            }
        } else {
            converterScrollView
        }
    }

    private var converterScrollView: some View {
        ScrollView {
            VStack(spacing: 12) {
                UnitToggle(selectedUnit: selectedUnitBinding)

                PaceInputRow(
                    paceMinutes: $paceMinutes,
                    paceSeconds: $paceSeconds,
                    paceLabel: selectedUnit.paceLabel
                )

                Divider()

                // Speed result
                VStack(spacing: 4) {
                    Text(ConversionEngine.formatSpeed(speed))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                    Text(selectedUnit.speedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .watchGlassCard()

                Divider()

                VStack(spacing: 8) {
                    NavigationLink("Reference Table") {
                        ReferenceTab()
                    }
                    .watchGlassButton()

                    NavigationLink("Race Calculator") {
                        RaceCalcTab()
                    }
                    .watchGlassButton()
                }
            }
            .padding(.horizontal)
        }
    }
}
