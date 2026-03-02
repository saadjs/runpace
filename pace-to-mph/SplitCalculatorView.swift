import SwiftUI

struct SplitCalculatorView: View {
    @State private var timeInput: String = ""
    @State private var selectedUnit: SpeedUnit = .mph
    @State private var selectedDistance: RaceCalculator.Distance = .fiveK
    @State private var customDistanceInput: String = ""
    @FocusState private var isTimeFocused: Bool
    @FocusState private var isDistanceFocused: Bool

    private var distanceInUnits: Double? {
        if selectedDistance == .custom {
            guard let val = Double(customDistanceInput), val > 0 else { return nil }
            return val
        }
        return selectedUnit == .mph ? selectedDistance.miles : selectedDistance.kilometers
    }

    private var paceText: String {
        guard let totalSeconds = RaceCalculator.parseDuration(timeInput),
              totalSeconds > 0,
              let distance = distanceInUnits,
              distance > 0 else { return "" }
        let paceMinutes = RaceCalculator.requiredPace(totalSeconds: totalSeconds, distanceInUnits: distance)
        guard let formatted = ConversionEngine.formatPace(paceMinutes) else { return "" }
        return formatted
    }

    private var speedText: String {
        guard let totalSeconds = RaceCalculator.parseDuration(timeInput),
              totalSeconds > 0,
              let distance = distanceInUnits,
              distance > 0 else { return "" }
        let paceMinutes = RaceCalculator.requiredPace(totalSeconds: totalSeconds, distanceInUnits: distance)
        let speed = ConversionEngine.paceToSpeed(paceMinutes)
        return ConversionEngine.formatSpeed(speed)
    }

    var body: some View {
        GlassEffectContainer {
            ScrollView {
                VStack(spacing: 20) {
                    // Time input card
                    VStack(spacing: 16) {
                        Text("Target Finish Time")
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

                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.green)
                            .frame(height: 2)
                            .frame(maxWidth: 200)
                    }
                    .padding(24)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))

                    // Unit picker
                    unitPicker

                    // Distance picker
                    distancePicker

                    // Custom distance input
                    if selectedDistance == .custom {
                        customDistanceField
                    }

                    // Result card
                    resultCard
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .onTapGesture {
            isTimeFocused = false
            isDistanceFocused = false
        }
        .navigationTitle("Even Splits")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Unit Picker

    private var unitPicker: some View {
        HStack(spacing: 16) {
            ForEach(SpeedUnit.allCases, id: \.self) { u in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        selectUnit(u)
                    }
                } label: {
                    Text(u == .mph ? "Mile" : "KM")
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

    // MARK: - Result

    private var resultCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Required Pace")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(paceText.isEmpty ? "–" : paceText)
                        .font(.largeTitle.bold().monospacedDigit())
                        .foregroundStyle(paceText.isEmpty ? .tertiary : .primary)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.2), value: paceText)

                    if !paceText.isEmpty {
                        Text(selectedUnit.paceLabel)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !speedText.isEmpty {
                Divider()

                VStack(spacing: 6) {
                    Text("Required Speed")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(0.6)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(speedText)
                            .font(.title.bold().monospacedDigit())
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.2), value: speedText)

                        Text(selectedUnit.speedLabel)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .sensoryFeedback(.impact(flexibility: .soft), trigger: paceText)
    }

    private func selectUnit(_ unit: SpeedUnit) {
        let previousUnit = selectedUnit
        guard previousUnit != unit else { return }

        customDistanceInput = ConversionEngine.convertDistanceInput(customDistanceInput, from: previousUnit, to: unit)
        selectedUnit = unit
    }
}

#Preview {
    NavigationStack {
        SplitCalculatorView()
    }
}
