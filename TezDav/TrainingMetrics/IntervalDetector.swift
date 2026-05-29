import Foundation
import SwiftData

struct IntervalDetector {
    /// Autodetect work/recovery interval segments from a chronologically sorted array of ActivityStreamSample.
    /// - Parameters:
    ///   - activityId: The unique ID of the activity.
    ///   - averageSpeed: The overall average speed of the activity (in m/s).
    ///   - samples: The list of second-by-second activity stream samples.
    /// - Returns: A list of detected `IntervalSegment` models.
    static func detectIntervals(
        activityId: Int64,
        averageSpeed: Double,
        samples: [ActivityStreamSample]
    ) -> [IntervalSegment] {
        guard averageSpeed > 0, samples.count > 30 else { return [] }
        
        let sortedSamples = samples.sorted { $0.offsetSeconds < $1.offsetSeconds }
        let size = sortedSamples.count
        
        // 1. Calculate a 5-second moving average for the speed stream to smooth GPS noise.
        var smoothedSpeeds = [Double](repeating: 0.0, count: size)
        for i in 0..<size {
            var sum = 0.0
            var count = 0
            let start = max(0, i - 2)
            let end = min(size - 1, i + 2)
            for j in start...end {
                if let spd = sortedSamples[j].speed {
                    sum += spd
                    count += 1
                }
            }
            smoothedSpeeds[i] = count > 0 ? (sum / Double(count)) : (sortedSamples[i].speed ?? averageSpeed)
        }
        
        // 2. Classify each second as Work (speed >= 110%), Recovery (speed <= 90%), or Neutral.
        let workThreshold = averageSpeed * 1.10
        let recoveryThreshold = averageSpeed * 0.90
        
        enum StateType {
            case work
            case recovery
            case neutral
        }
        
        var classifications = [StateType](repeating: .neutral, count: size)
        for i in 0..<size {
            let speed = smoothedSpeeds[i]
            if speed >= workThreshold {
                classifications[i] = .work
            } else if speed <= recoveryThreshold {
                classifications[i] = .recovery
            } else {
                classifications[i] = .neutral
            }
        }
        
        // 3. Extract continuous segments of Work and Recovery.
        struct RawSegment {
            let type: StateType
            let startIndex: Int
            let endIndex: Int
        }
        
        var rawSegments: [RawSegment] = []
        var currentType: StateType = classifications[0]
        var currentStart = 0
        
        for i in 1..<size {
            let type = classifications[i]
            if type != currentType {
                rawSegments.append(RawSegment(type: currentType, startIndex: currentStart, endIndex: i - 1))
                currentType = type
                currentStart = i
            }
        }
        rawSegments.append(RawSegment(type: currentType, startIndex: currentStart, endIndex: size - 1))
        
        // 4. Filter segments by duration thresholds (Work >= 20s, Recovery >= 15s)
        var candidates: [RawSegment] = []
        for seg in rawSegments {
            let duration = sortedSamples[seg.endIndex].offsetSeconds - sortedSamples[seg.startIndex].offsetSeconds
            if seg.type == .work && duration >= 20 {
                candidates.append(seg)
            } else if seg.type == .recovery && duration >= 15 {
                candidates.append(seg)
            }
        }
        
        // 5. Ensure alternating sequence: Work -> Recovery -> Work
        // We will loop through candidates and construct alternating segments.
        var alternatingRaw: [RawSegment] = []
        for cand in candidates {
            if let last = alternatingRaw.last {
                // If consecutive are the same type, we skip or could merge, but standard is to keep alternating.
                if last.type != cand.type {
                    alternatingRaw.append(cand)
                }
            } else {
                // First segment: let's prefer starting with a Work segment
                if cand.type == .work {
                    alternatingRaw.append(cand)
                }
            }
        }
        
        // Ensure we end with Work or Recovery properly.
        // We need at least 3 segments (e.g. Work, Recovery, Work) to count as an interval training.
        guard alternatingRaw.count >= 3 else { return [] }
        
        // 6. Build high-fidelity IntervalSegment SwiftData models.
        var result: [IntervalSegment] = []
        for (index, raw) in alternatingRaw.enumerated() {
            let rangeSamples = sortedSamples[raw.startIndex...raw.endIndex]
            
            let startDist = rangeSamples.first?.distanceMeters ?? 0.0
            let endDist = rangeSamples.last?.distanceMeters ?? startDist
            let duration = Double(rangeSamples.last!.offsetSeconds - rangeSamples.first!.offsetSeconds)
            
            // Calculate averages
            let speeds = rangeSamples.compactMap { $0.speed }
            let avgSpd = speeds.isEmpty ? averageSpeed : (speeds.reduce(0.0, +) / Double(speeds.count))
            
            let hrs = rangeSamples.compactMap { $0.heartRate }
            let avgHR = hrs.isEmpty ? nil : (hrs.reduce(0.0, +) / Double(hrs.count))
            
            let pows = rangeSamples.compactMap { $0.power }
            let avgPow = pows.isEmpty ? nil : (pows.reduce(0.0, +) / Double(pows.count))
            
            let segment = IntervalSegment(
                activityId: activityId,
                segmentIndex: index + 1,
                type: raw.type == .work ? "work" : "recovery",
                startDistanceMeters: startDist,
                endDistanceMeters: endDist,
                duration: duration,
                averageSpeed: avgSpd,
                averageHeartRate: avgHR,
                averagePower: avgPow
            )
            result.append(segment)
        }
        
        return result
    }
}
