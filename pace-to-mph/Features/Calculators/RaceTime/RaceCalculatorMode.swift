import Foundation

enum RaceCalculatorMode: String, CaseIterable, Hashable, Identifiable {
    case paceToTime
    case timeToPace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paceToTime: return "Pace → Time"
        case .timeToPace: return "Time → Pace"
        }
    }

    var inputTitle: String {
        switch self {
        case .paceToTime: return "PACE"
        case .timeToPace: return "FINISH TIME"
        }
    }

    var resultTitle: String {
        switch self {
        case .paceToTime: return "Finish Time"
        case .timeToPace: return "Target Pace"
        }
    }

    var systemImage: String {
        switch self {
        case .paceToTime: return "timer"
        case .timeToPace: return "figure.run"
        }
    }
}
