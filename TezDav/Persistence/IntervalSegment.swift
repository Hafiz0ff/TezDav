import Foundation
import SwiftData

@Model
final class IntervalSegment {
    var activityId: Int64
    var segmentIndex: Int
    var type: String // "work" (работа) or "recovery" (отдых)
    var startDistanceMeters: Double
    var endDistanceMeters: Double
    var duration: TimeInterval
    var averageSpeed: Double // meters per second
    var averageHeartRate: Double?
    var averagePower: Double?
    
    init(
        activityId: Int64,
        segmentIndex: Int,
        type: String,
        startDistanceMeters: Double,
        endDistanceMeters: Double,
        duration: TimeInterval,
        averageSpeed: Double,
        averageHeartRate: Double? = nil,
        averagePower: Double? = nil
    ) {
        self.activityId = activityId
        self.segmentIndex = segmentIndex
        self.type = type
        self.startDistanceMeters = startDistanceMeters
        self.endDistanceMeters = endDistanceMeters
        self.duration = duration
        self.averageSpeed = averageSpeed
        self.averageHeartRate = averageHeartRate
        self.averagePower = averagePower
    }
}
