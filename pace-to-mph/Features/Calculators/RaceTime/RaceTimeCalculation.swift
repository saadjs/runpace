import Foundation

/// A snapshot of race-calculator input. Parsing and results are independent of
/// SwiftUI focus, navigation, and storage, so they can be tested directly.
struct RaceTimeCalculation {
    let paceInput: String
    let timeInput: String
    let selectedUnit: SpeedUnit
    let selectedDistance: RaceCalculator.Distance
    let customDistanceInput: String

    // MARK: - Distance helpers

    var distanceInSelectedUnit: Double? {
        if selectedDistance == .custom {
            guard let val = Double(customDistanceInput), val > 0 else { return nil }
            return val
        }
        return selectedUnit == .mph ? selectedDistance.miles : selectedDistance.kilometers
    }

    func distance(in unit: SpeedUnit) -> Double? {
        if selectedDistance == .custom {
            guard let val = Double(customDistanceInput), val > 0 else { return nil }
            return ConversionEngine.convertDistanceBetweenUnits(val, from: selectedUnit, to: unit)
        }
        return selectedDistance.distance(unit: unit)
    }

    // MARK: - Pace → Time outputs

    var finishTimeText: String {
        guard let pace = ConversionEngine.parsePace(paceInput),
              let distance = distanceInSelectedUnit else { return "" }
        let seconds = RaceCalculator.finishTime(paceMinutes: pace, distanceInUnits: distance)
        return RaceCalculator.formatDuration(seconds)
    }

    var speedText: String {
        guard let pace = ConversionEngine.parsePace(paceInput) else { return "" }
        let speed = ConversionEngine.paceToSpeed(pace)
        return ConversionEngine.formatSpeed(speed)
    }

    // MARK: - Time → Pace outputs

    var parsedTimeSeconds: Int? {
        RaceCalculator.parseDuration(timeInput)
    }

    func targetPace(in unit: SpeedUnit) -> Double? {
        guard let seconds = parsedTimeSeconds,
              let dist = distance(in: unit),
              dist > 0 else { return nil }
        let pace = RaceCalculator.requiredPace(totalSeconds: seconds, distanceInUnits: dist)
        return pace > 0 ? pace : nil
    }

    func paceText(unit: SpeedUnit) -> String {
        guard let pace = targetPace(in: unit) else { return "" }
        return ConversionEngine.formatPace(pace) ?? ""
    }

    func speedTextForTargetPace(unit: SpeedUnit) -> String {
        guard let pace = targetPace(in: unit) else { return "" }
        return ConversionEngine.formatSpeed(ConversionEngine.paceToSpeed(pace))
    }

    var hasTargetPaceResult: Bool {
        targetPace(in: selectedUnit) != nil
    }

}
