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

    func distance(in unit: SpeedUnit) -> Double {
        unit == .mph ? distanceMiles : distanceKilometers
    }

    func paceMinutes(in unit: SpeedUnit) -> Double? {
        unit == .mph ? paceMinutesPerMile : paceMinutesPerKilometer
    }

    func averageSpeed(in unit: SpeedUnit) -> Double {
        unit == .mph ? averageSpeedMph : averageSpeedKph
    }

    /// Elevation gain in the unit system's display units, or nil when the
    /// source did not record it. A recorded flat run is 0, not nil.
    func elevationGain(in unit: SpeedUnit) -> Double? {
        guard let elevationGainMeters else { return nil }
        return unit == .mph ? elevationGainMeters * 3.28084 : elevationGainMeters
    }

    /// Heartbeats spent covering one mile/kilometre: average heart rate times
    /// the minutes run, divided by the distance. It pairs effort with output,
    /// so the same pace at a lower heart rate scores better. Lower is fitter,
    /// which is why trends on it read inverted from speed.
    ///
    /// Nil when the run carries no heart rate, which phone-logged runs often
    /// do not.
    func beatsPerDistanceUnit(in unit: SpeedUnit) -> Double? {
        guard let avgHeartRate, avgHeartRate > 0, duration > 0 else { return nil }
        let distance = distance(in: unit)
        guard distance > 0 else { return nil }
        return (Double(avgHeartRate) * (duration / 60.0)) / distance
    }
}
