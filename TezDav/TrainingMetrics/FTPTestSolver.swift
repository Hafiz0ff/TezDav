import Foundation

struct FTPTestSolver {
    
    /// Scans a cycling activity's samples, finds the 20-minute (1200 seconds) interval with the 
    /// maximum average power, and calculates FTP as 95% of that average.
    static func solveFTP(samples: [ActivityStreamSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        
        let sorted = samples.sorted(by: { $0.offsetSeconds < $1.offsetSeconds })
        guard let maxOffset = sorted.map({ $0.offsetSeconds }).max(), maxOffset >= 1200 else { return nil }
        
        // Re-sample power stream into 1Hz array of double values for continuous window calculation
        var continuousPower = [Double](repeating: 0.0, count: maxOffset + 1)
        for s in sorted {
            continuousPower[s.offsetSeconds] = s.power ?? 0.0
        }
        
        let windowSize = 1200 // 20 minutes
        guard continuousPower.count >= windowSize else { return nil }
        
        var currentSum = 0.0
        for i in 0..<windowSize {
            currentSum += continuousPower[i]
        }
        
        var maxSum = currentSum
        
        for i in windowSize..<continuousPower.count {
            currentSum = currentSum - continuousPower[i - windowSize] + continuousPower[i]
            if currentSum > maxSum {
                maxSum = currentSum
            }
        }
        
        let maxAveragePower20m = maxSum / Double(windowSize)
        return maxAveragePower20m * 0.95
    }
}
