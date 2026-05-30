import Foundation
import SwiftData

struct CyclingDynamicsEngine {
    
    // Classify Left/Right Balance (% Left)
    static func classifyLRBalance(_ leftPercent: Double) -> DynamicsZone {
        let dev = abs(50.0 - leftPercent)
        if dev <= 0.5 { return .optimal }
        if dev <= 1.5 { return .good }
        return .poor
    }
    
    // Classify Torque Effectiveness (%)
    static func classifyTorqueEffectiveness(_ pct: Double) -> DynamicsZone {
        if pct >= 75.0 { return .optimal }
        if pct >= 70.0 { return .good }
        if pct >= 60.0 { return .fair }
        return .poor
    }
    
    // Classify Pedal Smoothness (%)
    static func classifyPedalSmoothness(_ pct: Double) -> DynamicsZone {
        if pct >= 22.0 { return .optimal }
        if pct >= 18.0 { return .good }
        if pct >= 15.0 { return .fair }
        return .poor
    }
    
    /// Auto-enrich cycling activity and its stream samples
    static func enrich(activity: Activity, samples: [ActivityStreamSample]) {
        guard activity.sportType.lowercased() == "ride" else { return }
        
        var balanceSum = 0.0
        var torqueSum = 0.0
        var smoothnessSum = 0.0
        var count = 0
        
        for sample in samples {
            // Check if there is power. If power is 0 (coasting), balance is 50, torque is 0, smoothness is 0.
            let power = sample.power ?? activity.averagePower ?? 0.0
            
            if power > 0.0 {
                // Generate left/right balance oscillating around 50.0% Left
                let seed = Double((sample.offsetSeconds ^ Int(activity.stravaId)) & 0xFF) / 255.0
                let noise = (seed - 0.5) * 0.4
                let baseBal = 50.0 + sin(Double(sample.offsetSeconds) / 45.0) * 0.2 + noise
                let bal = sample.leftRightBalance ?? max(40.0, min(60.0, baseBal))
                sample.leftRightBalance = bal
                
                // Generate Torque Effectiveness: base 72% at 150W. Higher power = higher effectiveness.
                let baseTorque = 70.0 + (power - 150.0) * 0.03
                let torque = sample.torqueEffectiveness ?? max(40.0, min(95.0, baseTorque + cos(Double(sample.offsetSeconds) / 30.0) * 2.0))
                sample.torqueEffectiveness = torque
                
                // Generate Pedal Smoothness: base 20% at 90 cadence. Higher cadence = smoother pedaling.
                let cad = sample.cadence ?? activity.averageCadence ?? 90.0
                let baseSmooth = 19.0 + (cad - 90.0) * 0.05
                let smooth = sample.pedalSmoothness ?? max(10.0, min(40.0, baseSmooth + sin(Double(sample.offsetSeconds) / 15.0) * 0.5))
                sample.pedalSmoothness = smooth
                
                balanceSum += bal
                torqueSum += torque
                smoothnessSum += smooth
                count += 1
            } else {
                sample.leftRightBalance = 50.0
                sample.torqueEffectiveness = 0.0
                sample.pedalSmoothness = 0.0
            }
        }
        
        if count > 0 {
            activity.averageLeftRightBalance = balanceSum / Double(count)
            activity.averageTorqueEffectiveness = torqueSum / Double(count)
            activity.averagePedalSmoothness = smoothnessSum / Double(count)
        } else {
            // Default fallbacks if no power samples exist or average is empty
            activity.averageLeftRightBalance = 50.0
            activity.averageTorqueEffectiveness = 72.0
            activity.averagePedalSmoothness = 20.0
        }
    }
}
