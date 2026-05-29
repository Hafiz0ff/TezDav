import Foundation

struct PowerCurveCalculator {
    /// Calculates peak average powers for standard durations (1s, 5s, 15s, 30s, 1m, 2m, 5m, 10m, 20m, 60m).
    /// Returns a dictionary of duration in seconds to peak power in Watts.
    static func calculatePeaks(from samples: [ActivityStreamSample]) -> [Int: Double] {
        guard !samples.isEmpty else { return [:] }
        
        let sorted = samples.sorted { $0.offsetSeconds < $1.offsetSeconds }
        guard let maxOffset = sorted.last?.offsetSeconds else { return [:] }
        
        // Populate a contiguous array of second-by-second power values
        var powerStream = [Double](repeating: 0.0, count: maxOffset + 1)
        for sample in sorted {
            powerStream[sample.offsetSeconds] = sample.power ?? 0.0
        }
        
        let durations = [1, 5, 15, 30, 60, 120, 300, 600, 1200, 3600]
        var peaks: [Int: Double] = [:]
        
        for duration in durations {
            guard powerStream.count >= duration else { continue }
            
            var currentSum = 0.0
            for i in 0..<duration {
                currentSum += powerStream[i]
            }
            
            var maxSum = currentSum
            for i in duration..<powerStream.count {
                currentSum = currentSum - powerStream[i - duration] + powerStream[i]
                if currentSum > maxSum {
                    maxSum = currentSum
                }
            }
            
            peaks[duration] = maxSum / Double(duration)
        }
        
        return peaks
    }
}
