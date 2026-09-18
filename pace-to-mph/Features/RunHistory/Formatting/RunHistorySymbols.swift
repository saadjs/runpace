import Foundation

// One symbol per metric so a stat reads the same wherever it appears.
enum RunHistorySymbols {
    static let distance = "point.topleft.down.to.point.bottomright.curvepath"
    static let duration = "stopwatch"
    static let speed = "speedometer"
    static let pace = "gauge.with.dots.needle.67percent"
    static let runs = "figure.run"
    static let heartRate = "bolt.heart"
}
