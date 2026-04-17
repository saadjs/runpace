import SwiftUI

enum RaceCalculatorMode: String, CaseIterable, Identifiable {
    case paceToTime
    case timeToPace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paceToTime: return "Find Time"
        case .timeToPace: return "Find Pace"
        }
    }
}

struct RaceTimeView: View {
    @State private var mode: RaceCalculatorMode = .paceToTime
    @State private var paceInput: String = ""
    @State private var timeInput: String = ""
    @State private var selectedUnit: SpeedUnit = .mph
    @State private var selectedDistance: RaceCalculator.Distance = .fiveK
    @State private var customDistanceInput: String = ""
    @FocusState private var isPaceFocused: Bool
    @FocusState private var isTimeFocused: Bool
    @FocusState private var isDistanceFocused: Bool

    // MARK: - Distance helpers

    private var distanceInSelectedUnit: Double? {
        if selectedDistance == .custom {
            guard let val = Double(customDistanceInput), val > 0 else { return nil }
            return val
        }
        return selectedUnit == .mph ? selectedDistance.miles : selectedDistance.kilometers
    }

    private func distance(in unit: SpeedUnit) -> Double? {
        if selectedDistance == .custom {
            guard let val = Double(customDistanceInput), val > 0 else { return nil }
            return ConversionEngine.convertDistanceBetweenUnits(val, from: selectedUnit, to: unit)
        }
        return selectedDistance.distance(unit: unit)
    }

    // MARK: - Pace → Time outputs

    private var finishTimeText: String {
        guard let pace = ConversionEngine.parsePace(paceInput),
              let distance = distanceInSelectedUnit else { return "" }
        let seconds = RaceCalculator.finishTime(paceMinutes: pace, distanceInUnits: distance)
        return RaceCalculator.formatDuration(seconds)
    }

    private var speedText: String {
        guard let pace = ConversionEngine.parsePace(paceInput) else { return "" }
        let speed = ConversionEngine.paceToSpeed(pace)
        return ConversionEngine.formatSpeed(speed)
    }

    // MARK: - Time → Pace outputs

    private var parsedTimeSeconds: Int? {
        RaceCalculator.parseDuration(timeInput)
    }

    private func targetPace(in unit: SpeedUnit) -> Double? {
        guard let seconds = parsedTimeSeconds,
              let dist = distance(in: unit),
              dist > 0 else { return nil }
        let pace = RaceCalculator.requiredPace(totalSeconds: seconds, distanceInUnits: dist)
        return pace > 0 ? pace : nil
    }

    private func paceText(unit: SpeedUnit) -> String {
        guard let pace = targetPace(in: unit) else { return "" }
        return ConversionEngine.formatPace(pace) ?? ""
    }

    private func speedTextForTargetPace(unit: SpeedUnit) -> String {
        guard let pace = targetPace(in: unit) else { return "" }
        return ConversionEngine.formatSpeed(ConversionEngine.paceToSpeed(pace))
    }

    private var hasTargetPaceResult: Bool {
        targetPace(in: .mph) != nil && targetPace(in: .kph) != nil
    }

    // MARK: - Body

    var body: some View {
        GlassEffectContainer {
            ScrollView {
                VStack(spacing: 20) {
                    modePicker

                    if mode == .paceToTime {
                        paceInputCard
                    } else {
                        timeInputCard
                    }

                    if shouldShowUnitPicker {
                        unitPicker
                    }

                    distancePicker

                    if selectedDistance == .custom {
                        customDistanceField
                    }

                    if mode == .paceToTime {
                        finishResultCard
                    } else {
                        targetPaceResultCard
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .onTapGesture {
            isPaceFocused = false
            isTimeFocused = false
            isDistanceFocused = false
        }
        .navigationTitle("Race Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(RaceCalculatorMode.allCases) { m in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        mode = m
                        isPaceFocused = false
                        isTimeFocused = false
                    }
                } label: {
                    Text(m.label)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .tint(mode == m ? .green : nil)
                .accessibilityAddTraits(mode == m ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Race calculator mode")
    }

    // MARK: - Input Cards

    private var paceInputCard: some View {
        VStack(spacing: 16) {
            Text("PACE")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("mm:ss", text: $paceInput)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.plain)
                    .focused($isPaceFocused)
                    .minimumScaleFactor(0.5)
                    .onChange(of: paceInput) { _, newValue in
                        paceInput = newValue.filter { $0.isNumber || $0 == ":" || $0 == "." }
                    }

                Text(selectedUnit.paceLabel)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            accentRule
        }
        .padding(24)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
    }

    private var timeInputCard: some View {
        VStack(spacing: 16) {
            Text("FINISH TIME")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("h:mm:ss", text: $timeInput)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.plain)
                .focused($isTimeFocused)
                .minimumScaleFactor(0.5)
                .onChange(of: timeInput) { _, newValue in
                    timeInput = newValue.filter { $0.isNumber || $0 == ":" }
                }

            accentRule
        }
        .padding(24)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
    }

    private var accentRule: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.green)
            .frame(height: 2)
            .frame(maxWidth: 200)
    }

    // MARK: - Unit Picker

    private var shouldShowUnitPicker: Bool {
        mode == .paceToTime || selectedDistance == .custom
    }

    private var unitPicker: some View {
        HStack(spacing: 16) {
            ForEach(SpeedUnit.allCases, id: \.self) { u in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        selectUnit(u)
                    }
                } label: {
                    Text(u.paceLabel)
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1.5)
                }
                .buttonStyle(.glass)
                .tint(selectedUnit == u ? .green : nil)
            }
        }
    }

    // MARK: - Distance Picker

    private var distancePicker: some View {
        VStack(spacing: 8) {
            Text("Distance")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RaceCalculator.Distance.allCases) { d in
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                selectedDistance = d
                            }
                        } label: {
                            Text(d.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buttonStyle(.glass)
                        .tint(selectedDistance == d ? .green : nil)
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    // MARK: - Custom Distance

    private var customDistanceField: some View {
        VStack(spacing: 8) {
            Text("Custom Distance")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0.0", text: $customDistanceInput)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .focused($isDistanceFocused)
                    .onChange(of: customDistanceInput) { _, newValue in
                        customDistanceInput = newValue.filter { $0.isNumber || $0 == "." }
                    }

                Text(selectedUnit == .mph ? "miles" : "km")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    // MARK: - Result Cards

    private var finishResultCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Finish Time")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)

                Text(finishTimeText.isEmpty ? "–" : finishTimeText)
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(finishTimeText.isEmpty ? .tertiary : .primary)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: finishTimeText)
            }

            if !speedText.isEmpty {
                Divider()

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("PACE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .tracking(0.6)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(paceInput)
                                .font(.title2.bold().monospacedDigit())
                            Text(selectedUnit.paceLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: 4) {
                        Text("SPEED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .tracking(0.6)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(speedText)
                                .font(.title2.bold().monospacedDigit())
                                .contentTransition(.numericText())
                                .animation(.snappy(duration: 0.2), value: speedText)
                            Text(selectedUnit.speedLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .sensoryFeedback(.impact(flexibility: .soft), trigger: finishTimeText)
    }

    private var targetPaceResultCard: some View {
        VStack(spacing: 16) {
            Text("Target Pace")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.6)
                .foregroundStyle(.secondary)

            if hasTargetPaceResult {
                HStack(spacing: 0) {
                    paceColumn(unit: .mph)
                    Divider()
                        .frame(height: 72)
                    paceColumn(unit: .kph)
                }
            } else {
                Text("–")
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .sensoryFeedback(.impact(flexibility: .soft), trigger: paceText(unit: .mph) + paceText(unit: .kph))
    }

    private func paceColumn(unit: SpeedUnit) -> some View {
        let pace = paceText(unit: unit)
        let speed = speedTextForTargetPace(unit: unit)

        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(pace.isEmpty ? "–" : pace)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: pace)
                Text(unit.paceLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(speed.isEmpty ? "–" : speed)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: speed)
                Text(unit.speedLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func selectUnit(_ unit: SpeedUnit) {
        let previousUnit = selectedUnit
        guard previousUnit != unit else { return }

        paceInput = ConversionEngine.convertPaceInput(paceInput, from: previousUnit, to: unit)
        customDistanceInput = ConversionEngine.convertDistanceInput(customDistanceInput, from: previousUnit, to: unit)
        selectedUnit = unit
    }
}

#Preview {
    NavigationStack {
        RaceTimeView()
    }
}
