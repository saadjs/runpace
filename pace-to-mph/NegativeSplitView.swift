import SwiftUI

struct NegativeSplitView: View {
    @State private var timeInput: String = ""
    @State private var selectedUnit: SpeedUnit = .mph
    @State private var selectedDistance: RaceCalculator.Distance = .fiveK
    @State private var customDistanceInput: String = ""
    @State private var dropSecondsInput: String = "5"
    @FocusState private var isTimeFocused: Bool
    @FocusState private var isDistanceFocused: Bool
    @FocusState private var isDropFocused: Bool

    private var distanceInUnits: Double? {
        if selectedDistance == .custom {
            guard let val = Double(customDistanceInput), val > 0 else { return nil }
            return val
        }
        return selectedUnit == .mph ? selectedDistance.miles : selectedDistance.kilometers
    }

    private var dropSeconds: Double {
        Double(dropSecondsInput) ?? 0
    }

    private var splits: [(distance: Double, seconds: Int)] {
        guard let totalSeconds = RaceCalculator.parseDuration(timeInput),
              totalSeconds > 0,
              let distance = distanceInUnits,
              distance > 0 else { return [] }
        return RaceCalculator.negativeSplits(totalSeconds: totalSeconds, distanceInUnits: distance, dropSeconds: dropSeconds)
    }

    private var splitsFeedbackTrigger: Int {
        splits.reduce(17) { hash, split in
            let distanceMillis = Int((split.distance * 1_000).rounded())
            return ((hash &* 31) &+ distanceMillis) &+ split.seconds
        }
    }

    var body: some View {
        GlassEffectContainer {
            ScrollView {
                VStack(spacing: 20) {
                    // Target time input
                    VStack(spacing: 16) {
                        Text("TARGET TIME")
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

                    // Distance picker
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

                    // Custom distance
                    if selectedDistance == .custom {
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

                    // Drop per split input
                    VStack(spacing: 8) {
                        Text("DROP PER SPLIT")
                            .font(.caption)
                            .fontWeight(.bold)
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("5", text: $dropSecondsInput)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.plain)
                                .focused($isDropFocused)
                                .onChange(of: dropSecondsInput) { _, newValue in
                                    dropSecondsInput = newValue.filter { $0.isNumber }
                                }

                            Text("sec faster per \(selectedUnit == .mph ? "mile" : "km")")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))

                    // Splits list
                    if !splits.isEmpty {
                        splitsCard
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .onTapGesture {
            isTimeFocused = false
            isDistanceFocused = false
            isDropFocused = false
        }
        .navigationTitle("Negative Splits")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Splits Card

    private var splitsCard: some View {
        VStack(spacing: 12) {
            Text("SPLITS")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Header row
            HStack {
                Text("#")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)
                Text("Dist")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
                Spacer()
                Text("Split")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
                Text("Cumul.")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .trailing)
                Text("Pace")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }

            let cumulativeSeconds: [Int] = splits.reduce(into: []) { result, split in
                result.append((result.last ?? 0) + split.seconds)
            }

            ForEach(Array(splits.enumerated()), id: \.offset) { index, split in
                let cumulative = cumulativeSeconds[index]
                let paceMinutes = split.distance > 0 ? Double(split.seconds) / 60.0 / split.distance : 0

                HStack {
                    Text("\(index + 1)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 28, alignment: .leading)

                    Text(split.distance < 1.0 ? String(format: "%.2f", split.distance) : "1.00")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)

                    Spacer()

                    Text(RaceCalculator.formatDuration(split.seconds))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 64, alignment: .trailing)

                    Text(RaceCalculator.formatDuration(cumulative))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                        .frame(width: 72, alignment: .trailing)

                    Text(ConversionEngine.formatPace(paceMinutes) ?? "–")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }
                .padding(.vertical, 4)

                if index < splits.count - 1 {
                    Divider()
                }
            }
        }
        .padding(20)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .sensoryFeedback(.impact(flexibility: .soft), trigger: splitsFeedbackTrigger)
    }

    private func selectUnit(_ unit: SpeedUnit) {
        let previousUnit = selectedUnit
        guard previousUnit != unit else { return }

        customDistanceInput = ConversionEngine.convertDistanceInput(customDistanceInput, from: previousUnit, to: unit)

        if let dropSeconds = Double(dropSecondsInput), dropSeconds >= 0 {
            let convertedDrop = ConversionEngine.convertDropSecondsBetweenUnits(dropSeconds, from: previousUnit, to: unit)
            dropSecondsInput = String(Int(convertedDrop.rounded()))
        }

        selectedUnit = unit
    }
}

#Preview {
    NavigationStack {
        NegativeSplitView()
    }
}
