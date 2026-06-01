import Foundation
import SwiftData

struct ActivityMetricInput: Sendable {
    let date: Date
    let duration: TimeInterval
    let distanceMeters: Double
    let averageHeartRate: Double?
    let averagePower: Double?
    let sportType: String
}

struct FitnessPoint: Equatable, Sendable {
    let date: Date
    let ctl: Double
    let atl: Double
    let tsb: Double
}

enum TrainingLoadCalculator {
    static func trimp(duration: TimeInterval, averageHeartRate: Double?, restingHeartRate: Double = 60, maxHeartRate: Double) -> Double {
        guard let averageHeartRate, maxHeartRate > restingHeartRate, restingHeartRate > 0, duration > 0 else {
            return 0
        }

        let heartRateReserve = max(0, min(1, (averageHeartRate - restingHeartRate) / (maxHeartRate - restingHeartRate)))
        let minutes = duration / 60
        return minutes * heartRateReserve * 1.92 * exp(1.67 * heartRateReserve)
    }

    static func activityLoad(_ input: ActivityMetricInput, maxHeartRate: Double = 190) -> Double {
        let heartRateLoad = trimp(duration: input.duration, averageHeartRate: input.averageHeartRate, maxHeartRate: maxHeartRate)
        if heartRateLoad > 0 {
            return heartRateLoad
        }

        let hours = input.duration / 3600
        let distanceKm = input.distanceMeters / 1000
        let sportMultiplier = input.sportType.lowercased().contains("ride") ? 18.0 : 12.0
        return max(0, hours * 35 + distanceKm * sportMultiplier)
    }

    static func performanceManagement(loads: [(date: Date, load: Double)], initialCTL: Double = 0, initialATL: Double = 0) -> [FitnessPoint] {
        let sortedLoads = loads.sorted { $0.date < $1.date }
        var ctl = initialCTL
        var atl = initialATL

        return sortedLoads.map { item in
            ctl += (item.load - ctl) / 42
            atl += (item.load - atl) / 7
            return FitnessPoint(date: item.date, ctl: ctl, atl: atl, tsb: ctl - atl)
        }
    }

    // Calculates Normalized Power from raw power stream
    static func calculateNormalizedPower(from stream: [Double]) -> Double? {
        guard stream.count >= 30 else { return nil }
        var powersOfRollingAvgs: [Double] = []
        
        for i in 29..<stream.count {
            let sum = stream[(i-29)...i].reduce(0, +)
            let avg = sum / 30.0
            powersOfRollingAvgs.append(pow(avg, 4))
        }
        
        guard !powersOfRollingAvgs.isEmpty else { return nil }
        let meanOfPowers = powersOfRollingAvgs.reduce(0, +) / Double(powersOfRollingAvgs.count)
        return pow(meanOfPowers, 0.25)
    }

    // Dynamic historical recalculation of all training metrics for all activities
    @MainActor
    static func recalculateAllActivities(context: ModelContext, settings: UserSettings) {
        let descriptor = FetchDescriptor<Activity>()
        guard let activities = try? context.fetch(descriptor) else { return }

        let maxHR = settings.effectiveMaxHeartRate
        let restingHR = settings.restingHeartRate

        for activity in activities {
            // 1. Calculate TRIMP
            let trimpValue = trimp(
                duration: activity.movingTime,
                averageHeartRate: activity.averageHeartRate,
                restingHeartRate: restingHR,
                maxHeartRate: maxHR
            )
            activity.trimp = trimpValue

            // 2. Calculate dynamic Training Load
            var load = trimpValue
            let isCycling = activity.sportType.lowercased().contains("ride")

            if isCycling {
                // If it is cycling, try to calculate TSS using Normalized Power from streams
                let actId = activity.stravaId
                let sampleDescriptor = FetchDescriptor<ActivityStreamSample>(
                    predicate: #Predicate { $0.activityId == actId }
                )
                if let samples = try? context.fetch(sampleDescriptor), !samples.isEmpty {
                    let powerStream = samples.compactMap { $0.power }
                    if !powerStream.isEmpty {
                        if let np = calculateNormalizedPower(from: powerStream) {
                            let ftp = max(1.0, settings.cyclingFTP)
                            let intensityFactor = np / ftp
                            let tss = (activity.movingTime * np * intensityFactor) / (ftp * 3600.0) * 100.0
                            load = tss
                        }
                    }
                }
            }

            // Fallback load calculation if load is still zero or heart rate/power data was missing
            if load <= 0 {
                let input = ActivityMetricInput(
                    date: activity.startDate,
                    duration: activity.movingTime,
                    distanceMeters: activity.distanceMeters,
                    averageHeartRate: activity.averageHeartRate,
                    averagePower: activity.averagePower,
                    sportType: activity.sportType
                )
                load = activityLoad(input, maxHeartRate: maxHR)
            }

            activity.trainingLoad = load
        }

        try? context.save()
    }
}

