import AppIntents

enum SpeedUnitEntity: String, AppEnum {
    case mph = "MPH"
    case kph = "KM/H"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Speed Unit"

    static var caseDisplayRepresentations: [SpeedUnitEntity: DisplayRepresentation] = [
        .mph: "MPH",
        .kph: "KM/H",
    ]

    var speedUnit: SpeedUnit {
        switch self {
        case .mph: return .mph
        case .kph: return .kph
        }
    }
}
