import Foundation
import CoreLocation

struct RaceSplit: Identifiable, Sendable {
    let id = UUID()
    let number: Int
    let splitDistance: Double      // meters
    let cumulativeDistance: Double  // meters
    let splitDuration: TimeInterval  // seconds
    let cumulativeDuration: TimeInterval // seconds
    let elevationGain: Double      // meters
}

struct RacePredictorEngine {
    
    /// Calculates the dynamic Riegel exponent 'd' based on CTL (fitness).
    /// Standard Riegel uses 1.06. We adjust from 1.12 (low fitness, CTL=10) to 1.04 (high fitness, CTL=80).
    static func calculateExponent(ctl: Double) -> Double {
        let minCTL = 10.0
        let maxCTL = 80.0
        let clampedCTL = min(max(ctl, minCTL), maxCTL)
        let fraction = (clampedCTL - minCTL) / (maxCTL - minCTL) // 0.0 to 1.0
        return 1.12 - 0.08 * fraction
    }
    
    /// Calculates temperature penalty factor.
    /// Optimal temperature is 10°C.
    /// Heat slows down more on longer distances, hence distance ratio factor.
    static func calculateTemperatureFactor(temperature: Double, distance: Double) -> Double {
        if temperature > 12.0 {
            let degreesAbove = temperature - 12.0
            let distanceRatio = distance / 5000.0
            let penaltyPower = pow(max(distanceRatio, 0.1), 0.25)
            return 1.0 + 0.0015 * degreesAbove * penaltyPower
        } else if temperature < 5.0 {
            let degreesBelow = max(5.0 - temperature, 0.0)
            return 1.0 + 0.001 * min(degreesBelow, 20.0) // Max 2% penalty
        } else {
            return 1.0
        }
    }
    
    /// Adjusts flat distance to effective distance using elevation gain.
    /// 1 vertical meter is equivalent to 6 horizontal meters.
    static func calculateEffectiveDistance(distance: Double, elevationGain: Double) -> Double {
        return distance + 6.0 * elevationGain
    }
    
    /// Main prediction equation combining dynamic Riegel, elevation and temperature adjustments.
    static func predictTime(
        baseDistance: Double,
        baseTime: TimeInterval,
        targetDistance: Double,
        ctl: Double,
        elevationGain: Double,
        temperatureCelsius: Double
    ) -> TimeInterval {
        guard baseDistance > 0, targetDistance > 0, baseTime > 0 else { return 0 }
        
        let d = calculateExponent(ctl: ctl)
        let effectiveTargetDistance = max(0.1, calculateEffectiveDistance(distance: targetDistance, elevationGain: elevationGain))
        
        // Calculate standard Riegel time with effective distance
        let riegelTime = baseTime * pow(effectiveTargetDistance / baseDistance, d)
        
        // Apply temperature factor
        let tempFactor = calculateTemperatureFactor(temperature: temperatureCelsius, distance: targetDistance)
        
        return riegelTime * tempFactor
    }
    
    /// Computes cumulative elevation gain up to a specific distance based on the elevation profile.
    static func elevationGain(upTo distance: Double, profile: [ElevationPoint]) -> Double {
        guard profile.count > 1 else { return 0.0 }
        var gain = 0.0
        var prev = profile[0]
        
        for point in profile {
            if point.distance >= distance {
                // Interpolate height at exact boundary
                let denom = point.distance - prev.distance
                if denom > 0.001 {
                    let fraction = (distance - prev.distance) / denom
                    let targetElev = prev.elevation + fraction * (point.elevation - prev.elevation)
                    if targetElev > prev.elevation {
                        gain += (targetElev - prev.elevation)
                    }
                }
                break
            }
            if point.elevation > prev.elevation {
                gain += (point.elevation - prev.elevation)
            }
            prev = point
        }
        
        return gain
    }
    
    /// Generates splits table for a target race, taking Riegel fatigue curves and local segment slopes into account.
    static func generateSplits(
        baseDistance: Double,
        baseTime: TimeInterval,
        targetDistance: Double,
        ctl: Double,
        totalElevationGain: Double,
        temperatureCelsius: Double,
        elevationProfile: [ElevationPoint] = [],
        isMetric: Bool = true
    ) -> [RaceSplit] {
        guard baseDistance > 0, targetDistance > 0, baseTime > 0 else { return [] }
        
        let splitSize = isMetric ? 1000.0 : 1609.344 // 1 km or 1 mile
        let totalSplits = Int(ceil(targetDistance / splitSize))
        var splits: [RaceSplit] = []
        
        let d = calculateExponent(ctl: ctl)
        let tempFactor = calculateTemperatureFactor(temperature: temperatureCelsius, distance: targetDistance)
        
        var prevDistance = 0.0
        var prevDuration = 0.0
        var prevElevGain = 0.0
        
        for i in 1...totalSplits {
            let nextDistance = min(Double(i) * splitSize, targetDistance)
            let currentSplitDist = nextDistance - prevDistance
            
            // Calculate cumulative elevation gain at start and end of this split
            let cumulativeElevAtEnd: Double
            if elevationProfile.isEmpty {
                // Linearly distribute total elevation
                cumulativeElevAtEnd = (nextDistance / targetDistance) * totalElevationGain
            } else {
                cumulativeElevAtEnd = elevationGain(upTo: nextDistance, profile: elevationProfile)
            }
            
            let splitElevGain = max(cumulativeElevAtEnd - prevElevGain, 0.0)
            
            // Calculate effective cumulative distances
            let effDistanceEnd = calculateEffectiveDistance(distance: nextDistance, elevationGain: cumulativeElevAtEnd)
            
            // Riegel forecast for cumulative end point
            let cumulativeDurationAtEnd: TimeInterval
            if nextDistance >= targetDistance {
                // For final point, make sure it matches the exact prediction
                cumulativeDurationAtEnd = predictTime(
                    baseDistance: baseDistance,
                    baseTime: baseTime,
                    targetDistance: targetDistance,
                    ctl: ctl,
                    elevationGain: cumulativeElevAtEnd, // should match totalElevationGain or profile max
                    temperatureCelsius: temperatureCelsius
                )
            } else {
                let riegelFlat = baseTime * pow(effDistanceEnd / baseDistance, d)
                // We use cumulative temperature factor up to this point
                let currentTempFactor = calculateTemperatureFactor(temperature: temperatureCelsius, distance: nextDistance)
                cumulativeDurationAtEnd = riegelFlat * currentTempFactor
            }
            
            let splitDuration = max(cumulativeDurationAtEnd - prevDuration, 0.1)
            
            splits.append(RaceSplit(
                number: i,
                splitDistance: currentSplitDist,
                cumulativeDistance: nextDistance,
                splitDuration: splitDuration,
                cumulativeDuration: cumulativeDurationAtEnd,
                elevationGain: splitElevGain
            ))
            
            prevDistance = nextDistance
            prevDuration = cumulativeDurationAtEnd
            prevElevGain = cumulativeElevAtEnd
        }
        
        return splits
    }
}
