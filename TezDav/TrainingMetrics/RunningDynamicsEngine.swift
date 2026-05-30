import Foundation
import SwiftData

enum DynamicsZone: String, Codable, Sendable {
    case optimal = "optimal"   // Purple zone
    case good = "good"         // Green zone
    case fair = "fair"         // Orange zone
    case poor = "poor"         // Red zone
}

struct RunningDynamicsEngine {
    
    // Classify Cadence (spm)
    static func classifyCadence(_ spm: Double) -> DynamicsZone {
        if spm >= 180 { return .optimal }
        if spm >= 170 { return .good }
        if spm >= 160 { return .fair }
        return .poor
    }
    
    // Classify Vertical Oscillation (cm)
    static func classifyVerticalOscillation(_ cm: Double) -> DynamicsZone {
        if cm < 6.0 { return .optimal }
        if cm <= 8.5 { return .good }
        if cm <= 10.0 { return .fair }
        return .poor
    }
    
    // Classify Ground Contact Time (ms)
    static func classifyGCT(_ ms: Double) -> DynamicsZone {
        if ms < 200 { return .optimal }
        if ms <= 240 { return .good }
        if ms <= 300 { return .fair }
        return .poor
    }
    
    // Classify L/R Balance (% Left)
    static func classifyLRBalance(_ leftPercent: Double) -> DynamicsZone {
        let dev = abs(50.0 - leftPercent)
        if dev <= 0.5 { return .optimal }
        if dev <= 1.5 { return .good }
        return .poor
    }
    
    // Classify Stride Length (m)
    static func classifyStrideLength(_ meters: Double) -> DynamicsZone {
        if meters >= 1.2 { return .optimal }
        if meters >= 1.0 { return .good }
        if meters >= 0.8 { return .fair }
        return .poor
    }
    
    // Auto-enrich running activity and its stream samples
    static func enrich(activity: Activity, samples: [ActivityStreamSample]) {
        guard activity.sportType.lowercased() == "run" else { return }
        
        // 1. Generate dynamics for each sample if they are missing
        var oscSum = 0.0
        var gctSum = 0.0
        var strideSum = 0.0
        var balanceSum = 0.0
        var count = 0
        
        for sample in samples {
            // instant speed in m/s (default 3.0 = 5:33 min/km)
            let speed = sample.speed ?? activity.averageSpeed ?? 3.0
            // cadence in spm (default 170 spm)
            let cad = sample.cadence ?? activity.averageCadence ?? 170.0
            
            // 1. Stride Length = speed / (cadence / 60.0) = speed * 60.0 / cadence
            let stride = sample.strideLength ?? (cad > 0 ? (speed * 60.0) / cad : 1.0)
            sample.strideLength = stride
            
            // 2. Vertical Oscillation (cm)
            // base bounce: 8.5 cm. Decreases with higher cadence. Add variance based on speed and offset.
            let baseOsc = 8.5 - 0.05 * (cad - 170.0) + (speed - 3.0) * 0.4
            let osc = sample.verticalOscillation ?? max(4.0, min(15.0, baseOsc + sin(Double(sample.offsetSeconds) / 25.0) * 0.4))
            sample.verticalOscillation = osc
            
            // 3. Ground Contact Time (ms)
            // base contact: 240 ms. Decreases at higher speeds and higher cadence.
            let baseGCT = 240.0 - 15.0 * (speed - 3.0) + (170.0 - cad) * 0.8
            let gct = sample.groundContactTime ?? max(150.0, min(380.0, baseGCT + cos(Double(sample.offsetSeconds) / 15.0) * 6.0))
            sample.groundContactTime = gct
            
            // 4. L/R Balance (Left Ground Contact Time %)
            // Slow oscillation around 50%
            let seed = Double((sample.offsetSeconds ^ Int(activity.stravaId)) & 0xFF) / 255.0
            let noise = (seed - 0.5) * 0.3
            let baseBal = 50.0 + sin(Double(sample.offsetSeconds) / 80.0) * 0.3 + noise
            let bal = sample.leftGCTPercent ?? max(45.0, min(55.0, baseBal))
            sample.leftGCTPercent = bal
            
            oscSum += osc
            gctSum += gct
            strideSum += stride
            balanceSum += bal
            count += 1
        }
        
        // 2. Calculate and write averages to the Activity
        if count > 0 {
            activity.averageVerticalOscillation = oscSum / Double(count)
            activity.averageGroundContactTime = gctSum / Double(count)
            activity.averageStrideLength = strideSum / Double(count)
            activity.averageLeftGCTPercent = balanceSum / Double(count)
        } else {
            // Default fallbacks if no samples exist
            let avgSpeed = activity.averageSpeed ?? 3.0
            let avgCad = activity.averageCadence ?? 170.0
            activity.averageVerticalOscillation = 8.5
            activity.averageGroundContactTime = 240.0
            activity.averageStrideLength = avgCad > 0 ? (avgSpeed * 60.0) / avgCad : 1.0
            activity.averageLeftGCTPercent = 50.0
        }
    }
}
