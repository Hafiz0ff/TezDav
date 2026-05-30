import Foundation
import FitDataProtocol
import CoreLocation

struct FitParser {
    static func parse(url: URL) throws -> (activity: Activity, samples: [ActivityStreamSample]) {
        let fileData = try Data(contentsOf: url)
        var decoder = FitFileDecoder(crcCheckingStrategy: .throws)
        
        var points: [(date: Date, lat: Double, lon: Double, ele: Double?, hr: Double?, cad: Double?, power: Double?, speed: Double?, dist: Double?)] = []
        
        var activityName = "FIT Activity"
        var sportType = "Run"
        var startTime: Date?
        var totalDistance: Double?
        var totalElapsedTime: Double?
        var totalTimerTime: Double?
        var totalAscent: Double?
        var avgHeartRate: Double?
        var avgSpeed: Double?
        var avgPower: Double?
        var avgCadence: Double?
        
        try decoder.decode(data: fileData, messages: FitFileDecoder.defaultMessages, decoded: { (message: FitMessage) in
            if let record = message as? RecordMessage {
                guard let date = record.timeStamp?.recordDate else { return }
                
                // Coordinates
                var lat: Double?
                var lon: Double?
                
                if let pos = record.position,
                   let latMeasurement = pos.latitude,
                   let lonMeasurement = pos.longitude {
                    lat = latMeasurement.converted(to: .degrees).value
                    lon = lonMeasurement.converted(to: .degrees).value
                }
                
                // Telemetry
                let hr = record.heartRate?.value
                let cad = record.cadence?.value
                let power = record.power?.value
                
                // Handle possible Measurement or Double types
                var ele: Double? = nil
                if let altitude = record.altitude {
                    ele = altitude.converted(to: .meters).value
                }
                
                var spd: Double? = nil
                if let speed = record.speed {
                    spd = speed.converted(to: .metersPerSecond).value
                }
                
                var dist: Double? = nil
                if let distance = record.distance {
                    dist = distance.converted(to: .meters).value
                }
                
                if let validLat = lat, let validLon = lon {
                    points.append((
                        date: date,
                        lat: validLat,
                        lon: validLon,
                        ele: ele,
                        hr: hr,
                        cad: cad,
                        power: power,
                        speed: spd,
                        dist: dist
                    ))
                }
                
            } else if let session = message as? SessionMessage {
                if let start = session.startTime?.recordDate {
                    startTime = start
                }
                if let dist = session.totalDistance {
                    totalDistance = dist.converted(to: .meters).value
                }
                if let timer = session.totalTimerTime {
                    totalTimerTime = timer.converted(to: .seconds).value
                }
                if let elapsed = session.totalElapsedTime {
                    totalElapsedTime = elapsed.converted(to: .seconds).value
                }
                if let ascent = session.totalAscent {
                    totalAscent = ascent.converted(to: .meters).value
                }
                if let hr = session.averageHeartRate {
                    avgHeartRate = hr.value
                }
                if let speed = session.averageSpeed {
                    avgSpeed = speed.converted(to: .metersPerSecond).value
                }
                if let power = session.averagePower {
                    avgPower = power.value
                }
                if let cad = session.averageCadence {
                    avgCadence = cad.value
                }
                if let sport = session.sport?.stringValue {
                    sportType = sport
                }
            } else if let fileId = message as? FileIdMessage {
                if let prodName = fileId.productName {
                    activityName = prodName
                } else if let serial = fileId.deviceSerialNumber {
                    activityName = "Activity #\(serial)"
                }
            }
        })
        
        guard !points.isEmpty else {
            throw NSError(domain: "FitParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "FIT file contains no valid record coordinates."])
        }
        
        // Sort points chronologically
        let sortedPoints = points.sorted { $0.date < $1.date }
        let start = startTime ?? sortedPoints.first!.date
        let end = sortedPoints.last!.date
        
        let elapsed = end.timeIntervalSince(start)
        let movingTime = totalTimerTime ?? elapsed
        let finalDistance = totalDistance ?? (sortedPoints.last!.dist ?? 0.0)
        let elevationGain = totalAscent ?? 0.0
        
        let uniqueId = Int64(abs(start.timeIntervalSince1970.hashValue ^ url.deletingPathExtension().lastPathComponent.hashValue)) * -1
        let sport = mapSportType(sportType)
        
        var samples: [ActivityStreamSample] = []
        var hrCount = 0
        var hrSum = 0.0
        var cadCount = 0
        var cadSum = 0.0
        var powerCount = 0
        var powerSum = 0.0
        
        for (i, pt) in sortedPoints.enumerated() {
            let offset = Int(pt.date.timeIntervalSince(start))
            
            if let hr = pt.hr {
                hrCount += 1
                hrSum += hr
            }
            if let cad = pt.cad {
                cadCount += 1
                cadSum += cad
            }
            if let power = pt.power {
                powerCount += 1
                powerSum += power
            }
            
            samples.append(ActivityStreamSample(
                activityId: uniqueId,
                offsetSeconds: offset,
                distanceMeters: pt.dist ?? Double(i) * (finalDistance / Double(sortedPoints.count)),
                latitude: pt.lat,
                longitude: pt.lon,
                heartRate: pt.hr,
                cadence: pt.cad,
                power: pt.power,
                speed: pt.speed,
                altitude: pt.ele
            ))
        }
        
        let finalHR = avgHeartRate ?? (hrCount > 0 ? (hrSum / Double(hrCount)) : nil)
        let finalCad = avgCadence ?? (cadCount > 0 ? (cadSum / Double(cadCount)) : nil)
        let finalPower = avgPower ?? (powerCount > 0 ? (powerSum / Double(powerCount)) : nil)
        let finalSpeed = avgSpeed ?? (finalDistance / elapsed)
        
        // Calculate TRIMP and training load fallbacks
        let trimpVal = finalHR != nil ? Double(movingTime / 60.0) * 1.5 : 0.0
        let loadVal = finalHR != nil ? trimpVal * 1.1 : (finalDistance / 1000.0) * 3.5
        
        let name = activityName == "FIT Activity" ? url.deletingPathExtension().lastPathComponent : activityName
        
        let startLat = sortedPoints.first?.lat
        let startLon = sortedPoints.first?.lon
        
        let activity = Activity(
            stravaId: uniqueId,
            sportType: sport,
            name: name,
            startDate: start,
            distanceMeters: finalDistance,
            movingTime: movingTime,
            elapsedTime: elapsed,
            elevationGain: elevationGain,
            averageHeartRate: finalHR,
            averagePower: finalPower,
            averageCadence: finalCad,
            averageSpeed: finalSpeed,
            encodedPolyline: nil,
            trimp: trimpVal,
            trainingLoad: loadVal,
            importedAt: .now,
            streamsImported: true,
            source: "imported",
            startLatitude: startLat,
            startLongitude: startLon
        )
        
        let peaks = PowerCurveCalculator.calculatePeaks(from: samples)
        activity.peakPower1s = peaks[1]
        activity.peakPower5s = peaks[5]
        activity.peakPower15s = peaks[15]
        activity.peakPower30s = peaks[30]
        activity.peakPower1m = peaks[60]
        activity.peakPower2m = peaks[120]
        activity.peakPower5m = peaks[300]
        activity.peakPower10m = peaks[600]
        activity.peakPower20m = peaks[1200]
        activity.peakPower60m = peaks[3600]
        
        if sport == "Walk" || sport == "Hike" || sport == "Run" {
            let cad = finalCad ?? (sport == "Run" ? 85.0 : 50.0)
            let steps = Int(cad * 2.0 * (movingTime / 60.0))
            activity.stepsCount = steps
            activity.activeMinutes = Int(movingTime / 60.0)
            
            let elevations = sortedPoints.compactMap { $0.ele }
            activity.maxAltitude = elevations.max()
            
            var descent = 0.0
            for i in 1..<sortedPoints.count {
                if let prevEle = sortedPoints[i-1].ele, let currEle = sortedPoints[i].ele {
                    let diff = prevEle - currEle
                    if diff > 0 {
                        descent += diff
                    }
                }
            }
            activity.totalElevationLoss = descent
        } else if sport == "Swim" {
            let strokes = Int(finalDistance * 0.4)
            activity.swimStrokeCount = strokes
            activity.swimSWOLF = 40
            activity.pace100m = finalSpeed > 0 ? (100.0 / finalSpeed) : 0.0
            activity.activeMinutes = Int(movingTime / 60.0)
        }

        if sport == "Run" {
            RunningDynamicsEngine.enrich(activity: activity, samples: samples)
        } else if sport == "Ride" {
            CyclingDynamicsEngine.enrich(activity: activity, samples: samples)
        }
        
        return (activity, samples)
    }
    
    private static func mapSportType(_ rawType: String) -> String {
        let type = rawType.lowercased()
        if type.contains("bike") || type.contains("ride") || type.contains("cycl") {
            return "Ride"
        }
        if type.contains("walk") {
            return "Walk"
        }
        if type.contains("hike") {
            return "Hike"
        }
        if type.contains("swim") {
            return "Swim"
        }
        return "Run"
    }
}
