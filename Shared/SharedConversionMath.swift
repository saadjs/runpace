import Foundation

nonisolated enum SharedConversionMath {
    static func paceToSpeed(_ paceMinutes: Double) -> Double {
        60.0 / paceMinutes
    }

    static func speedToPace(_ speed: Double) -> Double {
        60.0 / speed
    }

    static func formatSpeed(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    static func formatPace(_ minutesPerUnit: Double) -> String? {
        guard minutesPerUnit.isFinite, minutesPerUnit > 0 else { return nil }

        let totalSeconds = Int(round(minutesPerUnit * 60))
        var minutes = totalSeconds / 60
        var seconds = totalSeconds % 60

        if seconds == 60 {
            minutes += 1
            seconds = 0
        }

        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    static func formatDuration(_ totalSeconds: Int) -> String {
        guard totalSeconds >= 0 else { return "0:00" }

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
        }

        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
