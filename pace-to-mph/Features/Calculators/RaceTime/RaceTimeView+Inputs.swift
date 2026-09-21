import SwiftUI

extension RaceTimeView {
    // MARK: - Mode Picker

    var modePicker: some View {
        Picker("Race calculator mode", selection: Binding(
            get: { mode },
            set: { selectedMode in
                withAnimation(.snappy(duration: 0.25)) {
                    mode = selectedMode
                    isPaceFocused = false
                    isTimeFocused = false
                }
            }
        )) {
            ForEach(RaceCalculatorMode.allCases) { m in
                Text(m.label).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .tint(.green)
    }

    // MARK: - Input Cards

    @ViewBuilder
    var inputCard: some View {
        switch mode {
        case .paceToTime:
            paceInputCard
        case .timeToPace:
            timeInputCard
        }
    }

    private var paceInputCard: some View {
        VStack(spacing: 16) {
            sectionLabel(mode.inputTitle)

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
        .autoFocus($isPaceFocused)
    }

    private var timeInputCard: some View {
        VStack(spacing: 16) {
            sectionLabel(mode.inputTitle)

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
        .autoFocus($isTimeFocused)
    }

    private var accentRule: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.green)
            .frame(height: 2)
            .frame(maxWidth: 200)
    }

    // MARK: - Distance Picker

    var distanceSection: some View {
        VStack(spacing: 14) {
            sectionLabel("DISTANCE")

            Picker("Distance", selection: $selectedDistance) {
                ForEach(RaceCalculator.Distance.allCases) { d in
                    Text(d.shortLabel).tag(d)
                }
            }
            .pickerStyle(.segmented)
            .tint(.green)

            if selectedDistance == .custom {
                Divider()
                customDistanceField
            }
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    // MARK: - Custom Distance

    private var customDistanceField: some View {
        VStack(spacing: 10) {
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

                Text(distanceLabel(for: selectedUnit))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

        }
    }

}
