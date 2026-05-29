import Foundation

struct PersonalRecordCalculator {
    // Calculates and updates all records for a given activity based on its stream samples
    static func calculateAndSetRecords(for activity: Activity, samples: [ActivityStreamSample]) {
        let isCycling = activity.sportType.lowercased().contains("ride")
        let isRunning = activity.sportType.lowercased().contains("run")
        
        if isRunning {
            // Running record distances
            activity.best1kTime = bestTime(for: 1000.0, in: samples)
            activity.best5kTime = bestTime(for: 5000.0, in: samples)
            activity.best10kTime = bestTime(for: 10000.0, in: samples)
            activity.bestHalfMarathonTime = bestTime(for: 21097.0, in: samples)
            activity.bestMarathonTime = bestTime(for: 42195.0, in: samples)
        } else if isCycling {
            // Cycling power curves
            activity.peakPower5s = peakPower(for: 5, in: samples)
            activity.peakPower1m = peakPower(for: 60, in: samples)
            activity.peakPower5m = peakPower(for: 300, in: samples)
            activity.peakPower20m = peakPower(for: 1200, in: samples)
            activity.peakPower60m = peakPower(for: 3600, in: samples)
            
            // Cycling speed records
            activity.best10kSpeedTime = bestTime(for: 10000.0, in: samples)
            activity.best40kSpeedTime = bestTime(for: 40000.0, in: samples)
        }
    }

    // Finds the best continuous time to cover a target distance in meters (O(N) sliding window)
    static func bestTime(for distance: Double, in samples: [ActivityStreamSample]) -> TimeInterval? {
        guard samples.count >= 2 else { return nil }
        
        // Check if the total activity covers the target distance
        let totalDistance = (samples.last?.distanceMeters ?? 0.0) - (samples.first?.distanceMeters ?? 0.0)
        guard totalDistance >= distance else { return nil }
        
        var bestTime = Double.infinity
        var left = 0
        
        for right in 0..<samples.count {
            let rightDist = samples[right].distanceMeters ?? 0.0
            
            // Advance left pointer to keep window size at least the target distance
            while left < right {
                let nextLeftDist = samples[left + 1].distanceMeters ?? 0.0
                if rightDist - nextLeftDist >= distance {
                    left += 1
                } else {
                    break
                }
            }
            
            let leftDist = samples[left].distanceMeters ?? 0.0
            if rightDist - leftDist >= distance {
                let timeTaken = Double(samples[right].offsetSeconds - samples[left].offsetSeconds)
                if timeTaken < bestTime {
                    bestTime = timeTaken
                }
            }
        }
        
        return bestTime == Double.infinity ? nil : bestTime
    }

    // Finds the peak average power for a duration in seconds (O(N) sliding window)
    static func peakPower(for seconds: Int, in samples: [ActivityStreamSample]) -> Double? {
        guard samples.count >= 2 else { return nil }
        
        // Check if the stream has power data
        let hasPower = samples.contains { $0.power != nil }
        guard hasPower else { return nil }
        
        var maxAvgPower = -1.0
        var left = 0
        var currentPowerSum = 0.0
        var count = 0
        
        for right in 0..<samples.count {
            let rightTime = samples[right].offsetSeconds
            let rightPower = samples[right].power ?? 0.0
            
            currentPowerSum += rightPower
            count += 1
            
            // Shrink window until duration is <= target seconds
            while left < right && (rightTime - samples[left].offsetSeconds) > seconds {
                let leftPower = samples[left].power ?? 0.0
                currentPowerSum -= leftPower
                count -= 1
                left += 1
            }
            
            let duration = rightTime - samples[left].offsetSeconds
            // Allow small buffer of 2 seconds for logging gaps
            if duration >= seconds - 2 && duration <= seconds + 2 && count > 0 {
                let avgPower = currentPowerSum / Double(count)
                if avgPower > maxAvgPower {
                    maxAvgPower = avgPower
                }
            }
        }
        
        return maxAvgPower == -1.0 ? nil : maxAvgPower
    }
}
