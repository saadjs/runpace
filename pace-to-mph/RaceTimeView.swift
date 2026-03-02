import SwiftUI

struct RaceTimeView: View {
    @State private var paceInput: String = ""
    @State private var selectedUnit: SpeedUnit = .mph
    @State private var selectedDistance: RaceCalculator.Distance = .fiveK
    @State private var customDistanceInput: String = ""
    @FocusState private var isPaceFocused: Bool
    @FocusState private var isDistanceFocused: Bool

    private var distanceInUnits: Double? {
        if selectedDistance == .custom {
            guard let val = Double(customDistanceInput), val > 0 else { return nil }
            return val
        }
        return selectedUnit == .mph ? selectedDistance.miles : selectedDistance.kilometers
    }

    private var finishTimeText: String {
        guard let pace = ConversionEngine.parsePace(paceInput),
              let distance = distanceInUnits else { return "" }
        let seconds = RaceCalculator.finishTime(paceMinutes: pace, distanceInUnits: distance)
        return RaceCalculator.formatDuration(seconds)
    }

    private var speedText: String {
        guard let pace = ConversionEngine.parsePace(paceInput) else { return "" }
        let speed = ConversionEngine.paceToSpeed(pace)
        return ConversionEngine.formatSpeed(speed)
    }

    var body: some View {
        GlassEffectContainer {
            ScrollView {
                VStack(spacing: 20) {
                    // Pace input card
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
            isPaceFocused = false
            isDistanceFocused = false
        }
        .navigationTitle("Race Finish Time")
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

    // MARK: - Result

    private var resultCard: some View {
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
