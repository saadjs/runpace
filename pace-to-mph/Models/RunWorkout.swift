import Foundation

nonisolated struct RunWorkout: Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let distanceMeters: Double
    let duration: TimeInterval
    let source: String
    /// Average heart rate in bpm, when the workout has it recorded. Apple Watch
    /// runs carry this; phone- or some third-party-logged runs may not.
    let avgHeartRate: Int?
    /// Total ascent recorded for the workout. Some sources do not provide it,
    /// so analytics must distinguish unavailable elevation from a true zero.
    let elevationGainMeters: Double?

    init(
        id: UUID,
        startDate: Date,
        endDate: Date,
        distanceMeters: Double,
        duration: TimeInterval,
        source: String,
        avgHeartRate: Int?,
        elevationGainMeters: Double? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.distanceMeters = distanceMeters
        self.duration = duration
        self.source = source
        self.avgHeartRate = avgHeartRate
        self.elevationGainMeters = elevationGainMeters
    }

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
