import Foundation

struct CriticalPowerSolver {
    struct CPResult {
        let criticalPower: Double // Watts
        let wPrime: Double // Joules (W')
        let isEstimated: Bool // false if regression succeeded, true if fallback used
    }
    
    /// Calculates CP and W' based on a list of MMP (duration -> Watts) values.
    /// Usually t1 = 5 min (300s) and t2 = 20 min (1200s).
    static func solve(mmp: [Int: Double], defaultFTP: Double = 250.0) -> CPResult {
        guard let p5m = mmp[300], p5m > 0,
              let p20m = mmp[1200], p20m > 0 else {
            // No 5m or 20m efforts found, fallback to FTP
            return CPResult(criticalPower: defaultFTP, wPrime: 18000.0, isEstimated: true)
        }
        
        let t1 = 300.0 // 5 mins
        let t2 = 1200.0 // 20 mins
        
        let e1 = p5m * t1
        let e2 = p20m * t2
        
        let cp = (e2 - e1) / (t2 - t1)
        let wPrime = e1 - cp * t1
        
        // Physiological checks:
        // - CP must be positive
        // - CP must be lower than p5m (since 5m power is always higher than CP)
        // - W' must be within a reasonable human range (e.g. 5,000 to 45,000 Joules)
        if cp > 0 && cp < p5m && wPrime >= 5000 && wPrime <= 45000 {
            return CPResult(criticalPower: cp, wPrime: wPrime, isEstimated: false)
        }
        
        // Fallback to FTP if calculation yields unphysiological numbers (e.g., if athlete didn't go all-out)
        return CPResult(criticalPower: defaultFTP, wPrime: 18000.0, isEstimated: true)
    }
}
