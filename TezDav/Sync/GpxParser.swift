import Foundation
import CoreLocation

struct GpxPoint {
    let lat: Double
    let lon: Double
    let elevation: Double?
    let time: Date
    var hr: Double?
    var cad: Double?
}

final class GpxParser: NSObject, XMLParserDelegate {
    private var points: [GpxPoint] = []
    
    // Parsing state
    private var currentElement = ""
    private var tempText = ""
    private var tempLat: Double?
    private var tempLon: Double?
    private var tempEle: Double?
    private var tempTime: Date?
    private var tempHr: Double?
    private var tempCad: Double?
    
    private var trackName = ""
    private var trackType = ""
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private let dateFormatterMs: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func parse(url: URL) throws -> (activity: Activity, samples: [ActivityStreamSample]) {
        let data = try Data(contentsOf: url)
        let parser = GpxParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        
        guard xmlParser.parse() else {
            throw xmlParser.parserError ?? NSError(domain: "GpxParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse GPX XML."])
        }
        
        return try parser.buildActivity(fileName: url.deletingPathExtension().lastPathComponent)
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        tempText = ""
        
        if elementName == "trkpt" {
            tempLat = nil
            tempLon = nil
            tempEle = nil
            tempTime = nil
            tempHr = nil
            tempCad = nil
            
            if let latStr = attributeDict["lat"], let lat = Double(latStr),
               let lonStr = attributeDict["lon"], let lon = Double(lonStr) {
                tempLat = lat
                tempLon = lon
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        tempText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "name":
            if trackName.isEmpty {
                trackName = tempText
            }
        case "type":
            if trackType.isEmpty {
                trackType = tempText
            }
        case "ele":
            tempEle = Double(tempText)
        case "time":
            if currentElement == "time" {
                tempTime = dateFormatter.date(from: tempText) ?? dateFormatterMs.date(from: tempText)
            }
        case "gpxtpx:hr", "hr":
            tempHr = Double(tempText)
        case "gpxtpx:cad", "cad":
            tempCad = Double(tempText)
        case "trkpt":
            if let lat = tempLat, let lon = tempLon, let time = tempTime {
                let pt = GpxPoint(
                    lat: lat,
                    lon: lon,
                    elevation: tempEle,
                    time: time,
                    hr: tempHr,
                    cad: tempCad
                )
                points.append(pt)
            }
        default:
            break
        }
        currentElement = ""
    }
    
    // MARK: - Core Logic Builders
    
    private func buildActivity(fileName: String) throws -> (activity: Activity, samples: [ActivityStreamSample]) {
        guard !points.isEmpty else {
            throw NSError(domain: "GpxParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "GPX file contains no valid trackpoints."])
        }
        
        // Sort points chronologically
        let sortedPoints = points.sorted { $0.time < $1.time }
        let startDate = sortedPoints.first!.time
        let endDate = sortedPoints.last!.time
        
        let elapsed = endDate.timeIntervalSince(startDate)
        
        var totalDist = 0.0
        var elevationGain = 0.0
        var samples: [ActivityStreamSample] = []
        
        // Differentiate running vs cycling based on GPX track type
        let sport = mapSportType(trackType)
        let uniqueId = Int64(abs(startDate.timeIntervalSince1970.hashValue ^ fileName.hashValue)) * -1
        
        // Construct first sample
        let firstPt = sortedPoints[0]
        samples.append(ActivityStreamSample(
            activityId: uniqueId,
            offsetSeconds: 0,
            distanceMeters: 0.0,
            latitude: firstPt.lat,
            longitude: firstPt.lon,
            heartRate: firstPt.hr,
            cadence: firstPt.cad,
            power: nil,
            speed: 0.0,
            altitude: firstPt.elevation
        ))
        
        var hrCount = firstPt.hr != nil ? 1 : 0
        var hrSum = firstPt.hr ?? 0.0
        var cadCount = firstPt.cad != nil ? 1 : 0
        var cadSum = firstPt.cad ?? 0.0
        
        for i in 1..<sortedPoints.count {
            let prev = sortedPoints[i-1]
            let curr = sortedPoints[i]
            
            let segmentDist = haversineDistance(lat1: prev.lat, lon1: prev.lon, lat2: curr.lat, lon2: curr.lon)
            totalDist += segmentDist
            
            if let currEle = curr.elevation, let prevEle = prev.elevation {
                let diff = currEle - prevEle
                if diff > 0 {
                    elevationGain += diff
                }
            }
            
            let offset = Int(curr.time.timeIntervalSince(startDate))
            let dt = curr.time.timeIntervalSince(prev.time)
            let currentSpeed = dt > 0 ? (segmentDist / dt) : 0.0
            
            if let hr = curr.hr {
                hrCount += 1
                hrSum += hr
            }
            if let cad = curr.cad {
                cadCount += 1
                cadSum += cad
            }
            
            samples.append(ActivityStreamSample(
                activityId: uniqueId,
                offsetSeconds: offset,
                distanceMeters: totalDist,
                latitude: curr.lat,
                longitude: curr.lon,
                heartRate: curr.hr,
                cadence: curr.cad,
                power: nil,
                speed: currentSpeed,
                altitude: curr.elevation
            ))
        }
        
        let avgHR = hrCount > 0 ? (hrSum / Double(hrCount)) : nil
        let avgCad = cadCount > 0 ? (cadSum / Double(cadCount)) : nil
        let avgSpeed = elapsed > 0 ? (totalDist / elapsed) : 0.0
        
        // Simple moving-time calculation: filter out periods of zero speed
        var movingTime = elapsed
        let activeSamples = samples.filter { ($0.speed ?? 0) > 0.5 }
        if activeSamples.count > 10 {
            movingTime = TimeInterval(activeSamples.count)
        }
        if movingTime > elapsed || movingTime <= 0 {
            movingTime = elapsed
        }
        
        // Calculate TRIMP and training load fallbacks
        let trimpVal = avgHR != nil ? Double(movingTime / 60.0) * 1.5 : 0.0
        let loadVal = avgHR != nil ? trimpVal * 1.1 : (totalDist / 1000.0) * 3.5 // fallback load
        
        let activityName = trackName.isEmpty ? fileName : trackName
        
        let activity = Activity(
            stravaId: uniqueId,
            sportType: sport,
            name: activityName,
            startDate: startDate,
            distanceMeters: totalDist,
            movingTime: movingTime,
            elapsedTime: elapsed,
            elevationGain: elevationGain,
            averageHeartRate: avgHR,
            averagePower: nil,
            averageCadence: avgCad,
            averageSpeed: avgSpeed,
            encodedPolyline: nil,
            trimp: trimpVal,
            trainingLoad: loadVal,
            importedAt: .now,
            streamsImported: true,
            source: "imported"
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
        
        if sport == "Run" {
            RunningDynamicsEngine.enrich(activity: activity, samples: samples)
        }
        
        return (activity, samples)
    }
    
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371000.0 // Earth radius in meters
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2.0) * sin(dLat / 2.0) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLon / 2.0) * sin(dLon / 2.0)
        let c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
        return r * c
    }
    
    private func mapSportType(_ rawType: String) -> String {
        let type = rawType.lowercased()
        if type.contains("bike") || type.contains("ride") || type.contains("cycl") {
            return "Ride"
        }
        return "Run"
    }
}
