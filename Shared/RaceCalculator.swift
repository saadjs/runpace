import Foundation

enum RaceCalculator {
    enum Distance: String, CaseIterable, Identifiable {
        case fiveK = "5K"
        case tenK = "10K"
        case halfMarathon = "Half Marathon"
        case marathon = "Marathon"
        case custom = "Custom"

        var id: String { rawValue }

        var miles: Double? {
            switch self {
            case .fiveK: return 3.10686
            case .tenK: return 6.21371
            case .halfMarathon: return 13.1094
            case .marathon: return 26.2188
            case .custom: return nil
            }
        }

        var kilometers: Double? {
            switch self {
            case .fiveK: return 5.0
            case .tenK: return 10.0
            case .halfMarathon: return 21.0975
            case .marathon: return 42.195
            case .custom: return nil
            }
        }

        var shortLabel: String {
            switch self {
            case .halfMarathon: return "Half"
            case .marathon: return "Full"
            default: return rawValue
            }
        }

        func distance(unit: SpeedUnit) -> Double? {
            switch unit {
            case .mph: return miles
            case .kph: return kilometers
            }
        }

        static var standardCases: [Distance] {
            allCases.filter { $0 != .custom }
        }
    }

    /// Given pace (min/mile or min/km) and distance in the same unit, return total seconds.
    static func finishTime(paceMinutes: Double, distanceInUnits: Double) -> Int {
        Int(round(paceMinutes * distanceInUnits * 60))
    }

    /// Format total seconds as "h:mm:ss" or "mm:ss" if under 1 hour.
    static func formatDuration(_ totalSeconds: Int) -> String {
        guard totalSeconds >= 0 else { return "0:00" }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
        } else {
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
    }

    /// Given finish time (total seconds) and distance, return pace in minutes.
    static func requiredPace(totalSeconds: Int, distanceInUnits: Double) -> Double {
        guard distanceInUnits > 0 else { return 0 }
        return Double(totalSeconds) / 60.0 / distanceInUnits
    }

    /// Parse "h:mm:ss" or "mm:ss" into total seconds, returns nil if invalid.
    static func parseDuration(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":")
        guard !parts.isEmpty, parts.count <= 3 else { return nil }

        let ints = parts.compactMap { Int($0) }
        guard ints.count == parts.count else { return nil }

        switch ints.count {
        case 1:
            // Just minutes
            guard ints[0] >= 0 else { return nil }
            return ints[0] * 60
        case 2:
            // mm:ss
            guard ints[0] >= 0, ints[1] >= 0, ints[1] < 60 else { return nil }
            return ints[0] * 60 + ints[1]
        case 3:
            // h:mm:ss
            guard ints[0] >= 0, ints[1] >= 0, ints[1] < 60, ints[2] >= 0, ints[2] < 60 else { return nil }
            return ints[0] * 3600 + ints[1] * 60 + ints[2]
        default:
            return nil
        }
    }

    /// Compute negative (progressive) splits.
    /// - Parameters:
    ///   - totalSeconds: Target finish time in seconds
    ///   - distanceInUnits: Total distance in miles or km
    ///   - dropSeconds: Seconds faster per split (positive value = each split is faster)
    /// - Returns: Array of (splitDistance, splitSeconds) tuples
    static func negativeSplits(totalSeconds: Int, distanceInUnits: Double, dropSeconds: Double) -> [(distance: Double, seconds: Int)] {
        guard distanceInUnits > 0, totalSeconds > 0, dropSeconds >= 0 else { return [] }

        let fullSplits = Int(distanceInUnits)
        let partial = distanceInUnits - Double(fullSplits)
        let splitCount = fullSplits + (partial > 0.001 ? 1 : 0)
        guard splitCount > 0 else { return [] }

        // Calculate base pace for first split such that total = totalSeconds
        // Split i has pace: basePace - i * dropSeconds (for full mile/km)
        // Last split is scaled by partial distance
        // Sum = sum(basePace - i*drop, i=0..fullSplits-1) + (basePace - fullSplits*drop)*partial
        // totalSeconds = fullSplits*basePace - drop*(0+1+...+(fullSplits-1)) + partial*(basePace - fullSplits*drop)
        // totalSeconds = basePace*(fullSplits + partial) - drop*(fullSplits*(fullSplits-1)/2 + partial*fullSplits)

        let n = Double(fullSplits)
        let effectiveDistance = n + (partial > 0.001 ? partial : 0)
        let dropSum = dropSeconds * (n * (n - 1) / 2 + (partial > 0.001 ? partial * n : 0))

        guard effectiveDistance > 0 else { return [] }
        let basePace = (Double(totalSeconds) + dropSum) / effectiveDistance
        guard basePace - Double(splitCount - 1) * dropSeconds > 0 else { return [] }

        var distances: [Double] = []
        var splitTimes: [Int] = []
        for i in 0..<splitCount {
            let splitPace = basePace - Double(i) * dropSeconds
            let dist: Double
            if i == splitCount - 1 && partial > 0.001 {
                dist = partial
            } else {
                dist = 1.0
            }
            let splitTime = max(Int(round(splitPace * dist)), 1)
            distances.append(dist)
            splitTimes.append(splitTime)
        }

        let difference = totalSeconds - splitTimes.reduce(0, +)
        if difference > 0 {
            // Add rounding remainder to the first (slowest) split to preserve non-increasing order
            splitTimes[0] += difference
        } else if difference < 0 {
            // Remove rounding overshoot from the end back toward the start. Each split can be
            // reduced only down to the next split (or 1s for the final split) so the result
            // stays non-increasing even when rounding produced equal adjacent splits.
            var overshoot = -difference
            for index in stride(from: splitTimes.count - 1, through: 0, by: -1) where overshoot > 0 {
                let minimum = index == splitTimes.count - 1 ? 1 : splitTimes[index + 1]
                let reducible = splitTimes[index] - minimum
                guard reducible >= 0 else { return [] }
                let adjustment = min(reducible, overshoot)
                splitTimes[index] -= adjustment
                overshoot -= adjustment
            }
            guard overshoot == 0 else { return [] }
        }

        return zip(distances, splitTimes).map { (distance: $0.0, seconds: $0.1) }
    }
}
