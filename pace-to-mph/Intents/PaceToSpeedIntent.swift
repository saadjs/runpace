import AppIntents

struct PaceToSpeedIntent: AppIntent {
    static var title: LocalizedStringResource = "Convert Pace to Speed"
    static var description = IntentDescription("Convert a running pace to speed in MPH or KPH")

    @Parameter(title: "Pace", description: "Running pace in mm:ss format, e.g. 7:30")
    var pace: String

    @Parameter(title: "Unit", description: "Speed unit", default: .mph)
    var unit: SpeedUnitEntity

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        guard let paceMinutes = ConversionEngine.parsePace(pace) else {
            throw $pace.needsValueError("Please provide a valid pace in mm:ss format, e.g. 7:30")
        }

        let speed = ConversionEngine.paceToSpeed(paceMinutes)
        let paceLabel = unit == .kph ? "per kilometer" : "per mile"

        let formatted = ConversionEngine.formatSpeed(speed)
        let dialog = "A pace of \(pace) \(paceLabel) is \(formatted) \(unit.rawValue)"

        return .result(value: formatted, dialog: IntentDialog(stringLiteral: dialog))
    }
}
