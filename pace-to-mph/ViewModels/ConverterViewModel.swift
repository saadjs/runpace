import SwiftUI

@Observable
final class ConverterViewModel {
    let history = ConversionHistory()

    var direction: ConversionDirection {
        didSet {
            storedDirection = direction.rawValue
            inputText = ""
        }
    }

    var unit: SpeedUnit {
        didSet {
            storedUnit = unit.rawValue
            convertInputForUnitChange(from: oldUnit, to: unit)
        }
    }

    var inputText: String = ""

    // Track old unit for input conversion on unit change
    private var oldUnit: SpeedUnit = .mph

    @ObservationIgnored
    @AppStorage("conversionDirection") private var storedDirection: String = ConversionDirection.paceToSpeed.rawValue

    @ObservationIgnored
    @AppStorage("speedUnit") private var storedUnit: String = SpeedUnit.mph.rawValue

    init() {
        let dir = ConversionDirection(rawValue: UserDefaults.standard.string(forKey: "conversionDirection") ?? "") ?? .paceToSpeed
        let u = SpeedUnit(rawValue: UserDefaults.standard.string(forKey: "speedUnit") ?? "") ?? .mph
        self.direction = dir
        self.unit = u
        self.oldUnit = u
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
        recordCurrentConversion()
        direction = newDirection
    }

    func recordCurrentConversion() {
        let currentResult = result
        guard !currentResult.isEmpty, !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        history.add(
            input: inputText,
            inputSuffix: inputSuffix,
            result: currentResult,
            resultSuffix: resultSuffix
        )
    }

    func switchUnit(to newUnit: SpeedUnit) {
        guard newUnit != unit else { return }
        recordCurrentConversion()
        oldUnit = unit
        unit = newUnit
    }

    // MARK: - Private

    private func convertInputForUnitChange(from oldUnit: SpeedUnit, to newUnit: SpeedUnit) {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        switch direction {
        case .paceToSpeed:
            guard let paceMinutes = ConversionEngine.parsePace(trimmed), paceMinutes > 0 else {
                inputText = ""
                return
            }
            let converted = ConversionEngine.convertPaceBetweenUnits(paceMinutes, from: oldUnit, to: newUnit)
            inputText = ConversionEngine.formatPace(converted) ?? ""

        case .speedToPace:
            guard let speed = ConversionEngine.parseSpeed(trimmed), speed > 0 else {
                inputText = ""
                return
            }
            let converted = ConversionEngine.convertSpeedBetweenUnits(speed, from: oldUnit, to: newUnit)
            inputText = ConversionEngine.formatSpeed(converted)
        }
    }
}
