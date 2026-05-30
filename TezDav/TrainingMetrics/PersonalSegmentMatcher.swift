import Foundation
import SwiftData
import CoreLocation

struct PersonalSegmentMatcher {
    // Calculates distance using Haversine formula
    static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371000.0 // meters
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }
    
    // Compute directed Hausdorff distance from set X to set Y
    static func directedHausdorffDistance(from X: [CLLocationCoordinate2D], to Y: [CLLocationCoordinate2D]) -> Double {
        var maxMinDist = 0.0
        for x in X {
            var minDist = Double.infinity
            for y in Y {
                let dist = haversineDistance(lat1: x.latitude, lon1: x.longitude, lat2: y.latitude, lon2: y.longitude)
                if dist < minDist {
                    minDist = dist
                }
            }
            if minDist > maxMinDist {
                maxMinDist = minDist
            }
        }
        return maxMinDist
    }
    
    // Bidirectional Hausdorff distance
    static func hausdorffDistance(_ X: [CLLocationCoordinate2D], _ Y: [CLLocationCoordinate2D]) -> Double {
        let d1 = directedHausdorffDistance(from: X, to: Y)
        let d2 = directedHausdorffDistance(from: Y, to: X)
        return max(d1, d2)
    }
    
    static func matchPersonalSegments(for activity: Activity, samples: [ActivityStreamSample], context: ModelContext) {
        guard !samples.isEmpty else { return }
        
        let segmentsDescriptor = FetchDescriptor<PersonalSegment>()
        guard let segments = try? context.fetch(segmentsDescriptor), !segments.isEmpty else { return }
        
        let isCycling = activity.sportType.lowercased().contains("ride")
        let isRunning = activity.sportType.lowercased().contains("run")
        let activityId = activity.stravaId
        
        // Delete existing efforts for this personal segment & activity
        let effortPredicate = #Predicate<SegmentEffort> { effort in
            effort.activityId == activityId && effort.personalSegment != nil
        }
        try? context.delete(model: SegmentEffort.self, where: effortPredicate)
        try? context.save()
        
        // Map samples coordinates
        let sampleCoords = samples.map { sample -> CLLocationCoordinate2D? in
            guard let lat = sample.latitude, let lon = sample.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        for segment in segments {
            let segmentIsRun = segment.sportType.lowercased().contains("run")
            let segmentIsRide = segment.sportType.lowercased().contains("ride")
            
            if (segmentIsRun && !isRunning) || (segmentIsRide && !isCycling) {
                continue
            }
            
            let segmentCoords = segment.coordinates
            guard segmentCoords.count >= 2 else { continue }
            
            // Find points near segment start and end
            var startIndices: [Int] = []
            var endIndices: [Int] = []
            
            for (idx, coordOpt) in sampleCoords.enumerated() {
                guard let coord = coordOpt else { continue }
                
                let distToStart = haversineDistance(lat1: coord.latitude, lon1: coord.longitude, lat2: segment.startLatitude, lon2: segment.startLongitude)
                if distToStart <= 30.0 {
                    startIndices.append(idx)
                }
                
                let distToEnd = haversineDistance(lat1: coord.latitude, lon1: coord.longitude, lat2: segment.endLatitude, lon2: segment.endLongitude)
                if distToEnd <= 30.0 {
                    endIndices.append(idx)
                }
            }
            
            var detectedEfforts: [(startIdx: Int, endIdx: Int, duration: TimeInterval, dist: Double)] = []
            
            for startIdx in startIndices {
                for endIdx in endIndices {
                    guard startIdx < endIdx else { continue }
                    
                    let duration = TimeInterval(samples[endIdx].offsetSeconds - samples[startIdx].offsetSeconds)
                    guard duration > 0 else { continue }
                    
                    let startDist = samples[startIdx].distanceMeters ?? 0.0
                    let endDist = samples[endIdx].distanceMeters ?? 0.0
                    let realDist = endDist - startDist
                    
                    // Verify distance matching within 20% tolerance
                    let diffPercent = abs(realDist - segment.distanceMeters) / segment.distanceMeters
                    if diffPercent <= 0.20 {
                        // Extract sub-route from activity
                        let subCoords = sampleCoords[startIdx...endIdx].compactMap { $0 }
                        guard subCoords.count >= 2 else { continue }
                        
                        // Calculate Hausdorff distance
                        let hDist = hausdorffDistance(segmentCoords, subCoords)
                        if hDist <= 30.0 {
                            detectedEfforts.append((startIdx: startIdx, endIdx: endIdx, duration: duration, dist: realDist))
                        }
                    }
                }
            }
            
            // Select the fastest one
            if let bestEffort = detectedEfforts.min(by: { $0.duration < $1.duration }) {
                var hrSum = 0.0
                var hrCount = 0
                var powerSum = 0.0
                var powerCount = 0
                
                for idx in bestEffort.startIdx...bestEffort.endIdx {
                    let s = samples[idx]
                    if let hr = s.heartRate {
                        hrSum += hr
                        hrCount += 1
                    }
                    if let powVal = s.power {
                        powerSum += powVal
                        powerCount += 1
                    }
                }
                
                let avgHR = hrCount > 0 ? (hrSum / Double(hrCount)) : nil
                let avgPower = powerCount > 0 ? (powerSum / Double(powerCount)) : nil
                let avgSpeed = bestEffort.dist / bestEffort.duration
                
                let newEffort = SegmentEffort(
                    activityId: activityId,
                    activityName: activity.name,
                    athleteName: "Вы",
                    startDate: activity.startDate.addingTimeInterval(TimeInterval(samples[bestEffort.startIdx].offsetSeconds)),
                    elapsedTime: bestEffort.duration,
                    averageHeartRate: avgHR,
                    averagePower: avgPower,
                    averageSpeed: avgSpeed,
                    isMock: false
                )
                
                newEffort.personalSegment = segment
                context.insert(newEffort)
                segment.efforts.append(newEffort)
            }
        }
        
        try? context.save()
    }
}
