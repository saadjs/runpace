import SwiftUI

struct RaceTimeView: View {
    @State var mode: RaceCalculatorMode = .paceToTime
    @State var paceInput: String = ""
    @State var timeInput: String = ""
    @State var settings = UnitSettings.shared
    @State var selectedDistance: RaceCalculator.Distance = .fiveK
    @State var customDistanceInput: String = ""
    @FocusState var isPaceFocused: Bool
    @FocusState var isTimeFocused: Bool
    @FocusState var isDistanceFocused: Bool

    var selectedUnit: SpeedUnit { settings.unit }

    var calculation: RaceTimeCalculation {
        RaceTimeCalculation(
            paceInput: paceInput,
            timeInput: timeInput,
            selectedUnit: selectedUnit,
            selectedDistance: selectedDistance,
            customDistanceInput: customDistanceInput
        )
    }

    // MARK: - Body

    var body: some View {
        GlassEffectContainer {
            ScrollView {
                VStack(spacing: 16) {
                    modePicker
                    inputCard
                    distanceSection
                    resultCard
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

    func sectionLabel(_ text: String, alignment: Alignment = .leading) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    func distanceLabel(for unit: SpeedUnit) -> String {
        unit == .mph ? "miles" : "km"
    }
}

#Preview {
    NavigationStack {
        RaceTimeView()
    }
}
