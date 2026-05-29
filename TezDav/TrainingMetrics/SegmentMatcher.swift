import Foundation
import SwiftData
import CoreLocation

struct SegmentMatcher {
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
    
    static func matchSegments(for activity: Activity, samples: [ActivityStreamSample], context: ModelContext) {
        guard !samples.isEmpty else { return }
        
        // Seed segments if empty
        let segmentsDescriptor = FetchDescriptor<Segment>()
        if let segments = try? context.fetch(segmentsDescriptor), segments.isEmpty {
            seedSegments(context: context)
        }
        
        // Re-fetch segments
        guard let segments = try? context.fetch(segmentsDescriptor) else { return }
        performMatching(for: activity, samples: samples, segments: segments, context: context)
    }
    
    private static func performMatching(for activity: Activity, samples: [ActivityStreamSample], segments: [Segment], context: ModelContext) {
        let isCycling = activity.sportType.lowercased().contains("ride")
        let isRunning = activity.sportType.lowercased().contains("run")
        
        let activityId = activity.stravaId
        
        // 1. Delete existing non-mock efforts for this activity to be idempotent
        let effortPredicate = #Predicate<SegmentEffort> { effort in
            effort.activityId == activityId
        }
        try? context.delete(model: SegmentEffort.self, where: effortPredicate)
        try? context.save()
        
        // 2. Scan segments
        for segment in segments {
            // Sport type filter
            let segmentIsRun = segment.sportType.lowercased().contains("run")
            let segmentIsRide = segment.sportType.lowercased().contains("ride")
            
            if (segmentIsRun && !isRunning) || (segmentIsRide && !isCycling) {
                continue
            }
            
            // Find points near segment start and end
            var startIndices: [Int] = []
            var endIndices: [Int] = []
            
            for (idx, sample) in samples.enumerated() {
                guard let lat = sample.latitude, let lon = sample.longitude else { continue }
                
                let distToStart = haversineDistance(lat1: lat, lon1: lon, lat2: segment.startLatitude, lon2: segment.startLongitude)
                if distToStart <= 25.0 {
                    startIndices.append(idx)
                }
                
                let distToEnd = haversineDistance(lat1: lat, lon1: lon, lat2: segment.endLatitude, lon2: segment.endLongitude)
                if distToEnd <= 25.0 {
                    endIndices.append(idx)
                }
            }
            
            // Find valid pairs
            var detectedEfforts: [(startIdx: Int, endIdx: Int, duration: TimeInterval, dist: Double)] = []
            
            for startIdx in startIndices {
                for endIdx in endIndices {
                    guard startIdx < endIdx else { continue }
                    
                    let duration = TimeInterval(samples[endIdx].offsetSeconds - samples[startIdx].offsetSeconds)
                    guard duration > 0 else { continue }
                    
                    let startDist = samples[startIdx].distanceMeters ?? 0.0
                    let endDist = samples[endIdx].distanceMeters ?? 0.0
                    let realDist = endDist - startDist
                    
                    // Verify distance matching within 15% tolerance
                    let diffPercent = abs(realDist - segment.distanceMeters) / segment.distanceMeters
                    if diffPercent <= 0.15 {
                        detectedEfforts.append((startIdx: startIdx, endIdx: endIdx, duration: duration, dist: realDist))
                    }
                }
            }
            
            // Select the fastest one if multiple overlapping attempts are found
            if let bestEffort = detectedEfforts.min(by: { $0.duration < $1.duration }) {
                // Calculate average HR, Power, Speed
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
                
                newEffort.segment = segment
                context.insert(newEffort)
                segment.efforts.append(newEffort)
            }
        }
        
        try? context.save()
    }
    
    private static func interpolateCoordinates(startLat: Double, startLon: Double, endLat: Double, endLon: Double, pointsCount: Int) -> [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        for i in 0..<pointsCount {
            let t = Double(i) / Double(pointsCount - 1)
            let lat = startLat + (endLat - startLat) * t
            let lon = startLon + (endLon - startLon) * t
            coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        return coords
    }
    
    static func seedSegments(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Segment>())) ?? 0
        guard count == 0 else { return }
        
        // 1. «Спринт на Рудаки» (Run)
        let rudakiCoords = interpolateCoordinates(startLat: 38.5739, startLon: 68.7979, endLat: 38.5784, endLon: 68.7973, pointsCount: 10)
        let rudaki = Segment(
            name: "Спринт на Рудаки",
            sportType: "Run",
            distanceMeters: 503.0,
            averageGrade: 0.4,
            elevationGain: 2.0,
            startLatitude: 38.5739,
            startLongitude: 68.7979,
            endLatitude: 38.5784,
            endLongitude: 68.7973
        )
        rudaki.coordinates = rudakiCoords
        context.insert(rudaki)
        
        let rudakiBots: [(String, Double, Double?, Double?)] = [
            ("Иван Иванов", 95.0, 168.0, nil),
            ("Алексей Смирнов", 102.0, 172.0, nil),
            ("Мария Петрова", 115.0, 165.0, nil),
            ("Фируз Саидов", 125.0, 160.0, nil),
            ("Дилшод Рахимов", 138.0, 155.0, nil)
        ]
        for (name, time, hr, power) in rudakiBots {
            let effort = SegmentEffort(
                athleteName: name,
                startDate: Date().addingTimeInterval(-86400 * Double.random(in: 1...5)),
                elapsedTime: time,
                averageHeartRate: hr,
                averagePower: power,
                averageSpeed: 503.0 / time,
                isMock: true
            )
            effort.segment = rudaki
            context.insert(effort)
            rudaki.efforts.append(effort)
        }
        
        // 2. «Подъем к амфитеатру» (Run)
        let amphitheaterCoords = interpolateCoordinates(startLat: 38.5830, startLon: 68.7845, endLat: 38.5910, endLon: 68.7780, pointsCount: 10)
        let amphitheater = Segment(
            name: "Подъем к амфитеатру",
            sportType: "Run",
            distanceMeters: 1100.0,
            averageGrade: 4.1,
            elevationGain: 45.0,
            startLatitude: 38.5830,
            startLongitude: 68.7845,
            endLatitude: 38.5910,
            endLongitude: 68.7780
        )
        amphitheater.coordinates = amphitheaterCoords
        context.insert(amphitheater)
        
        let ampBots: [(String, Double, Double?, Double?)] = [
            ("Алексей Смирнов", 270.0, 175.0, nil),
            ("Иван Иванов", 295.0, 170.0, nil),
            ("Фируз Саидов", 312.0, 174.0, nil),
            ("Мария Петрова", 340.0, 169.0, nil),
            ("Дилшод Рахимов", 390.0, 162.0, nil)
        ]
        for (name, time, hr, power) in ampBots {
            let effort = SegmentEffort(
                athleteName: name,
                startDate: Date().addingTimeInterval(-86400 * Double.random(in: 1...5)),
                elapsedTime: time,
                averageHeartRate: hr,
                averagePower: power,
                averageSpeed: 1100.0 / time,
                isMock: true
            )
            effort.segment = amphitheater
            context.insert(effort)
            amphitheater.efforts.append(effort)
        }
        
        // 3. «Велопетля Сарез» (Ride)
        let sarezCoords = interpolateCoordinates(startLat: 38.5520, startLon: 68.7510, endLat: 38.5680, endLon: 68.7850, pointsCount: 10)
        let sarez = Segment(
            name: "Велопетля Сарез",
            sportType: "Ride",
            distanceMeters: 3400.0,
            averageGrade: 0.4,
            elevationGain: 15.0,
            startLatitude: 38.5520,
            startLongitude: 68.7510,
            endLatitude: 38.5680,
            endLongitude: 68.7850
        )
        sarez.coordinates = sarezCoords
        context.insert(sarez)
        
        let sarezBots = [
            ("Фируз Саидов", 300.0, 155.0, 280.0),
            ("Дилшод Рахимов", 325.0, 158.0, 260.0),
            ("Алексей Смирнов", 360.0, 162.0, 240.0),
            ("Иван Иванов", 400.0, 150.0, 220.0),
            ("Мария Петрова", 450.0, 145.0, 195.0)
        ]
        for (name, time, hr, power) in sarezBots {
            let effort = SegmentEffort(
                athleteName: name,
                startDate: Date().addingTimeInterval(-86400 * Double.random(in: 1...5)),
                elapsedTime: time,
                averageHeartRate: hr,
                averagePower: power,
                averageSpeed: 3400.0 / time,
                isMock: true
            )
            effort.segment = sarez
            context.insert(effort)
            sarez.efforts.append(effort)
        }
        
        // 4. «Подъем на Варзоб» (Ride)
        let varzobCoords = interpolateCoordinates(startLat: 38.6410, startLon: 68.7810, endLat: 38.6700, endLon: 68.7910, pointsCount: 10)
        let varzob = Segment(
            name: "Подъем на Варзоб",
            sportType: "Ride",
            distanceMeters: 3300.0,
            averageGrade: 5.4,
            elevationGain: 180.0,
            startLatitude: 38.6410,
            startLongitude: 68.7810,
            endLatitude: 38.6700,
            endLongitude: 68.7910
        )
        varzob.coordinates = varzobCoords
        context.insert(varzob)
        
        let varzobBots = [
            ("Дилшод Рахимов", 450.0, 172.0, 310.0),
            ("Фируз Саидов", 510.0, 169.0, 290.0),
            ("Алексей Смирнов", 580.0, 174.0, 260.0),
            ("Иван Иванов", 660.0, 160.0, 235.0),
            ("Мария Петрова", 720.0, 165.0, 210.0)
        ]
        for (name, time, hr, power) in varzobBots {
            let effort = SegmentEffort(
                athleteName: name,
                startDate: Date().addingTimeInterval(-86400 * Double.random(in: 1...5)),
                elapsedTime: time,
                averageHeartRate: hr,
                averagePower: power,
                averageSpeed: 3300.0 / time,
                isMock: true
            )
            effort.segment = varzob
            context.insert(effort)
            varzob.efforts.append(effort)
        }
        
        try? context.save()
    }
}
