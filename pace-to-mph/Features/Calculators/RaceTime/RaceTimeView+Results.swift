import SwiftUI

extension RaceTimeView {
    // MARK: - Result Cards

    @ViewBuilder
    var resultCard: some View {
        switch mode {
        case .paceToTime:
            finishResultCard
        case .timeToPace:
            targetPaceResultCard
        }
    }

    private var finishResultCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                sectionLabel(mode.resultTitle, alignment: .center)

                Text(calculation.finishTimeText.isEmpty ? "–" : calculation.finishTimeText)
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(calculation.finishTimeText.isEmpty ? .tertiary : .primary)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: calculation.finishTimeText)
            }

            if !calculation.speedText.isEmpty {
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
                            Text(calculation.speedText)
                                .font(.title2.bold().monospacedDigit())
                                .contentTransition(.numericText())
                                .animation(.snappy(duration: 0.2), value: calculation.speedText)
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
        .sensoryFeedback(.impact(flexibility: .soft), trigger: calculation.finishTimeText)
    }

    private var targetPaceResultCard: some View {
        VStack(spacing: 16) {
            sectionLabel(mode.resultTitle, alignment: .center)

            if calculation.hasTargetPaceResult {
                paceColumn(unit: selectedUnit)
            } else {
                Text("–")
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .sensoryFeedback(.impact(flexibility: .soft), trigger: calculation.paceText(unit: selectedUnit))
    }

    private func paceColumn(unit: SpeedUnit) -> some View {
        let pace = calculation.paceText(unit: unit)
        let speed = calculation.speedTextForTargetPace(unit: unit)

        return VStack(spacing: 10) {
            Text(unit == .mph ? "MILE" : "KILOMETER")
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(0.6)
                .foregroundStyle(.secondary)

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

}
