import AppIntents

struct SpeedToPaceIntent: AppIntent {
    static var title: LocalizedStringResource = "Convert Speed to Pace"
    static var description = IntentDescription("Convert a speed in MPH or KPH to a running pace")

    @Parameter(title: "Speed", description: "Speed value, e.g. 8.0")
    var speed: Double

    @Parameter(title: "Unit", description: "Speed unit", default: .mph)
    var unit: SpeedUnitEntity

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        guard speed > 0 else {
            throw $speed.needsValueError("Please provide a speed greater than zero")
        }

        let paceMinutes = ConversionEngine.speedToPace(speed)

        guard let formatted = ConversionEngine.formatPace(paceMinutes) else {
            throw $speed.needsValueError("Could not convert that speed to a pace")
        }

        let paceUnit = unit == .kph ? "/km" : "/mi"
        let dialog = "\(ConversionEngine.formatSpeed(speed)) \(unit.rawValue) is a \(formatted) \(paceUnit) pace"

        return .result(value: formatted, dialog: IntentDialog(stringLiteral: dialog))
    }
}
