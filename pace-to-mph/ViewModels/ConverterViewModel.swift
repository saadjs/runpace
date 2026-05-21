import SwiftUI

@Observable
final class ConverterViewModel {
    var direction: ConversionDirection {
        didSet {
            storedDirection = direction.rawValue
            inputText = ""
        }
    }

    var inputText: String = ""

    var unit: SpeedUnit {
        UnitSettings.shared.unit
    }

    @ObservationIgnored
    @AppStorage("conversionDirection") private var storedDirection: String = ConversionDirection.paceToSpeed.rawValue

    init() {
        let dir = ConversionDirection(rawValue: UserDefaults.standard.string(forKey: "conversionDirection") ?? "") ?? .paceToSpeed
        self.direction = dir
    }

    // MARK: - Computed

    var result: String {
        ConversionEngine.convert(direction: direction, input: inputText)
    }

    var placeholder: String {
        switch direction {
        case .paceToSpeed: return "mm:ss"
        case .speedToPace: return unit == .mph ? "10.00" : "16.00"
        }
    }

    var inputSuffix: String {
        switch direction {
        case .paceToSpeed: return unit.paceLabel
        case .speedToPace: return unit.speedLabel
        }
    }

    var resultSuffix: String {
        switch direction {
        case .paceToSpeed: return unit.speedLabel
        case .speedToPace: return unit.paceLabel
        }
    }

    var helperText: String {
        switch direction {
        case .paceToSpeed:
            return "Enter pace \(unit == .mph ? "per mile" : "per km") to get speed"
        case .speedToPace:
            return "Enter speed in \(unit.label) to get pace"
        }
    }

    var directionLabel: String {
        direction.label
    }

    // MARK: - Actions

    func handleInput(_ value: String) {
        inputText = ConversionEngine.sanitizeInput(direction: direction, value: value)
    }

    func switchDirection(to newDirection: ConversionDirection) {
        guard newDirection != direction else { return }
        direction = newDirection
    }

    // Called when the global unit changes. The typed value's meaning
    // (e.g. min/mi vs min/km) would silently flip, so we clear it.
    func handleUnitChange() {
        inputText = ""
    }
}
