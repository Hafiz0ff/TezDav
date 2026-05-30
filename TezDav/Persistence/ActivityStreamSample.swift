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
    var verticalOscillation: Double? // in cm
    var groundContactTime: Double?  // in ms
    var strideLength: Double?       // in meters
    var leftGCTPercent: Double?     // in %
    
    // Cycling Dynamics
    var leftRightBalance: Double?   // in % Left
    var torqueEffectiveness: Double? // in %
    var pedalSmoothness: Double?     // in %

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
        altitude: Double? = nil,
        verticalOscillation: Double? = nil,
        groundContactTime: Double? = nil,
        strideLength: Double? = nil,
        leftGCTPercent: Double? = nil,
        leftRightBalance: Double? = nil,
        torqueEffectiveness: Double? = nil,
        pedalSmoothness: Double? = nil
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
        self.verticalOscillation = verticalOscillation
        self.groundContactTime = groundContactTime
        self.strideLength = strideLength
        self.leftGCTPercent = leftGCTPercent
        self.leftRightBalance = leftRightBalance
        self.torqueEffectiveness = torqueEffectiveness
        self.pedalSmoothness = pedalSmoothness
    }
}
