import Foundation
import SwiftData

@Model
final class Activity {
    @Attribute(.unique) var stravaId: Int64
    var sportType: String
    var name: String
    var startDate: Date
    var distanceMeters: Double
    var movingTime: TimeInterval
    var elapsedTime: TimeInterval
    var elevationGain: Double
    var averageHeartRate: Double?
    var averagePower: Double?
    var averageCadence: Double?
    var averageSpeed: Double?
    var encodedPolyline: String?
    var trimp: Double
    var trainingLoad: Double
    var importedAt: Date
    var streamsImported: Bool
    var source: String = "strava"

    // Gear & Weather Correlation
    var startLatitude: Double?
    var startLongitude: Double?
    var gearItem: GearItem?
    var weatherSnapshot: WeatherSnapshot?

    // Running Dynamics
    var averageVerticalOscillation: Double? // in cm
    var averageGroundContactTime: Double?  // in ms
    var averageStrideLength: Double?       // in meters
    var averageLeftGCTPercent: Double?     // in %

    // Advanced Cycling Dynamics
    var isFTPTest: Bool = false
    var averageLeftRightBalance: Double?     // in % Left
    var averageTorqueEffectiveness: Double?  // in %
    var averagePedalSmoothness: Double?      // in %
    
    // Route matching
    var isPlanned: Bool = false
    var plannedRouteId: UUID?

    // Running records (seconds taken to cover the distance)
    var best1kTime: TimeInterval?
    var best5kTime: TimeInterval?
    var best10kTime: TimeInterval?
    var bestHalfMarathonTime: TimeInterval?
    var bestMarathonTime: TimeInterval?

    // Cycling power records (peak average Watts for duration)
    var peakPower1s: Double?
    var peakPower5s: Double?
    var peakPower15s: Double?
    var peakPower30s: Double?
    var peakPower1m: Double?
    var peakPower2m: Double?
    var peakPower5m: Double?
    var peakPower10m: Double?
    var peakPower20m: Double?
    var peakPower60m: Double?

    // Cycling speed records (seconds taken)
    var best10kSpeedTime: TimeInterval?
    var best40kSpeedTime: TimeInterval?

    // Casual, Walk, Hike, Swim specific metrics
    var stepsCount: Int?
    var activeMinutes: Int?
    var maxAltitude: Double?
    var totalElevationLoss: Double?
    var swimStrokeCount: Int?
    var swimSWOLF: Int?
    var pace100m: Double?

    init(
        stravaId: Int64,
        sportType: String,
        name: String,
        startDate: Date,
        distanceMeters: Double,
        movingTime: TimeInterval,
        elapsedTime: TimeInterval,
        elevationGain: Double,
        averageHeartRate: Double? = nil,
        averagePower: Double? = nil,
        averageCadence: Double? = nil,
        averageSpeed: Double? = nil,
        encodedPolyline: String? = nil,
        trimp: Double,
        trainingLoad: Double,
        importedAt: Date = .now,
        streamsImported: Bool = false,
        source: String = "strava",
        averageVerticalOscillation: Double? = nil,
        averageGroundContactTime: Double? = nil,
        averageStrideLength: Double? = nil,
        averageLeftGCTPercent: Double? = nil,
        best1kTime: TimeInterval? = nil,
        best5kTime: TimeInterval? = nil,
        best10kTime: TimeInterval? = nil,
        bestHalfMarathonTime: TimeInterval? = nil,
        bestMarathonTime: TimeInterval? = nil,
        peakPower1s: Double? = nil,
        peakPower5s: Double? = nil,
        peakPower15s: Double? = nil,
        peakPower30s: Double? = nil,
        peakPower1m: Double? = nil,
        peakPower2m: Double? = nil,
        peakPower5m: Double? = nil,
        peakPower10m: Double? = nil,
        peakPower20m: Double? = nil,
        peakPower60m: Double? = nil,
        best10kSpeedTime: TimeInterval? = nil,
        best40kSpeedTime: TimeInterval? = nil,
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        isFTPTest: Bool = false,
        averageLeftRightBalance: Double? = nil,
        averageTorqueEffectiveness: Double? = nil,
        averagePedalSmoothness: Double? = nil,
        isPlanned: Bool = false,
        plannedRouteId: UUID? = nil,
        stepsCount: Int? = nil,
        activeMinutes: Int? = nil,
        maxAltitude: Double? = nil,
        totalElevationLoss: Double? = nil,
        swimStrokeCount: Int? = nil,
        swimSWOLF: Int? = nil,
        pace100m: Double? = nil
    ) {
        self.stravaId = stravaId
        self.sportType = sportType
        self.name = name
        self.startDate = startDate
        self.distanceMeters = distanceMeters
        self.movingTime = movingTime
        self.elapsedTime = elapsedTime
        self.elevationGain = elevationGain
        self.averageHeartRate = averageHeartRate
        self.averagePower = averagePower
        self.averageCadence = averageCadence
        self.averageSpeed = averageSpeed
        self.encodedPolyline = encodedPolyline
        self.trimp = trimp
        self.trainingLoad = trainingLoad
        self.importedAt = importedAt
        self.streamsImported = streamsImported
        self.source = source
        self.averageVerticalOscillation = averageVerticalOscillation
        self.averageGroundContactTime = averageGroundContactTime
        self.averageStrideLength = averageStrideLength
        self.averageLeftGCTPercent = averageLeftGCTPercent
        self.best1kTime = best1kTime
        self.best5kTime = best5kTime
        self.best10kTime = best10kTime
        self.bestHalfMarathonTime = bestHalfMarathonTime
        self.bestMarathonTime = bestMarathonTime
        self.peakPower1s = peakPower1s
        self.peakPower5s = peakPower5s
        self.peakPower15s = peakPower15s
        self.peakPower30s = peakPower30s
        self.peakPower1m = peakPower1m
        self.peakPower2m = peakPower2m
        self.peakPower5m = peakPower5m
        self.peakPower10m = peakPower10m
        self.peakPower20m = peakPower20m
        self.peakPower60m = peakPower60m
        self.best10kSpeedTime = best10kSpeedTime
        self.best40kSpeedTime = best40kSpeedTime
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.isFTPTest = isFTPTest
        self.averageLeftRightBalance = averageLeftRightBalance
        self.averageTorqueEffectiveness = averageTorqueEffectiveness
        self.averagePedalSmoothness = averagePedalSmoothness
        self.isPlanned = isPlanned
        self.plannedRouteId = plannedRouteId
        self.stepsCount = stepsCount
        self.activeMinutes = activeMinutes
        self.maxAltitude = maxAltitude
        self.totalElevationLoss = totalElevationLoss
        self.swimStrokeCount = swimStrokeCount
        self.swimSWOLF = swimSWOLF
        self.pace100m = pace100m
    }
}
