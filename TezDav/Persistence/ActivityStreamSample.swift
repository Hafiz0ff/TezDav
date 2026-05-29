import Foundation
import SwiftData

@Model
final class ActivityStreamSample {
    var activityId: Int64
    var offsetSeconds: Int
    var distanceMeters: Double?
    var latitude: Double?
    var longitude: Double?
    var heartRate: Double?
    var cadence: Double?
    var power: Double?
    var speed: Double?
    var altitude: Double?

    init(
        activityId: Int64,
        offsetSeconds: Int,
        distanceMeters: Double? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        heartRate: Double? = nil,
        cadence: Double? = nil,
        power: Double? = nil,
        speed: Double? = nil,
        altitude: Double? = nil
    ) {
        self.activityId = activityId
        self.offsetSeconds = offsetSeconds
        self.distanceMeters = distanceMeters
        self.latitude = latitude
        self.longitude = longitude
        self.heartRate = heartRate
        self.cadence = cadence
        self.power = power
        self.speed = speed
        self.altitude = altitude
    }
}
