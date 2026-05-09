import Foundation

struct RunWorkout: Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let distanceMeters: Double
    let duration: TimeInterval
    let source: String

    var distanceMiles: Double { distanceMeters / 1609.34 }
    var distanceKilometers: Double { distanceMeters / 1000.0 }

    var averageSpeedMph: Double {
        guard duration > 0 else { return 0 }
        return distanceMiles / (duration / 3600.0)
    }

    var averageSpeedKph: Double {
        guard duration > 0 else { return 0 }
        return distanceKilometers / (duration / 3600.0)
    }

    /// Pace in minutes per mile.
    var paceMinutesPerMile: Double? {
        guard distanceMiles > 0 else { return nil }
        return (duration / 60.0) / distanceMiles
    }

    /// Pace in minutes per kilometer.
    var paceMinutesPerKilometer: Double? {
        guard distanceKilometers > 0 else { return nil }
        return (duration / 60.0) / distanceKilometers
    }
}
