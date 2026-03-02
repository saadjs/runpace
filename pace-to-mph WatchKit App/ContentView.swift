import SwiftUI

// MARK: - Pace Entry

private struct PaceEntry: Identifiable {
    let min: Int
    let sec: Int
    var id: Int { min * 60 + sec }
    var paceMinutes: Double { Double(min) + Double(sec) / 60.0 }
    var label: String { "\(min):\(String(format: "%02d", sec))" }
}

// MARK: - Inline Pace Picker

private struct PaceInputRow: View {
    @Binding var paceMinutes: Int
    @Binding var paceSeconds: Int
    let paceLabel: String

    @State private var editingSeconds = false
    @State private var crownValue: Double = 0

    private var crownMax: Double { editingSeconds ? 59 : 30 }
    private var crownMin: Double { editingSeconds ? 0 : 1 }

    var body: some View {
        HStack(spacing: 4) {
            Text("\(paceMinutes)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(!editingSeconds ? Color.green : Color.white.opacity(0.3), lineWidth: 2)
                )
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    editingSeconds = false
                    crownValue = Double(paceMinutes)
                }

            Text(":")
                .font(.title3.bold())

            Text(String(format: "%02d", paceSeconds))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(editingSeconds ? Color.green : Color.white.opacity(0.3), lineWidth: 2)
                )
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    editingSeconds = true
                    crownValue = Double(paceSeconds)
                }

            Text(paceLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .focusable()
        .digitalCrownRotation(
            detent: $crownValue,
            from: crownMin, through: crownMax, by: 1,
            sensitivity: .low,
            isContinuous: false
        )
        .onChange(of: crownValue) { _, newValue in
            if editingSeconds {
                paceSeconds = Int(newValue)
            } else {
                paceMinutes = Int(newValue)
            }
        }
        .onAppear { crownValue = Double(paceMinutes) }
    }
}

// MARK: - Custom Selectors

private struct UnitToggle: View {
    @Binding var selectedUnit: SpeedUnit

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SpeedUnit.allCases, id: \.self) { unit in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedUnit = unit }
                } label: {
                    Text(unit.speedLabel)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedUnit == unit ? .white : .secondary)
                .background(
                    selectedUnit == unit ? Color.green : Color.white.opacity(0.08),
                    in: Capsule()
                )
            }
        }
    }
}

private struct DistanceSelector: View {
    @Binding var selected: RaceCalculator.Distance

    private let distances = RaceCalculator.Distance.standardCases

    var body: some View {
        HStack(spacing: 4) {
            ForEach(distances) { distance in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selected = distance }
                } label: {
                    Text(distance.shortLabel)
                        .font(.caption2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selected == distance ? .white : .secondary)
                .background(
                    selected == distance ? Color.green : Color.white.opacity(0.08),
                    in: Capsule()
                )
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func watchGlassCard(cornerRadius: CGFloat = 16) -> some View {
        if #available(watchOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func watchGlassButton() -> some View {
        if #available(watchOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

// MARK: - Main View

struct ContentView: View {
    var body: some View {
        ConverterTab()
    }
}

// MARK: - Reference Tab

private struct ReferenceTab: View {
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

// MARK: - Shared Helpers

private func makeUnitBinding(
    unit: Binding<SpeedUnit>,
    paceMinutes: Binding<Int>,
    paceSeconds: Binding<Int>
) -> Binding<SpeedUnit> {
    Binding(
        get: { unit.wrappedValue },
        set: { newUnit in
            let previousUnit = unit.wrappedValue
            guard previousUnit != newUnit else { return }

            if let converted = ConversionEngine.convertPaceComponents(
                minutes: paceMinutes.wrappedValue,
                seconds: paceSeconds.wrappedValue,
                from: previousUnit,
                to: newUnit
            ) {
                paceMinutes.wrappedValue = converted.minutes
                paceSeconds.wrappedValue = converted.seconds
            }

            unit.wrappedValue = newUnit
        }
    )
}

// MARK: - Converter Tab

private struct ConverterTab: View {
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

// MARK: - Race Calculator Tab

private struct RaceCalcTab: View {
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

#Preview {
    ContentView()
}
