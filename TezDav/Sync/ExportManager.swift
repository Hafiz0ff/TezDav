// swiftlint:disable cyclomatic_complexity
import Foundation
import SwiftData

struct ExportManager {
    /// Formats an activity as a standard GPX 1.1 file string with Garmin extensions.
    static func exportToGPX(activity: Activity, samples: [ActivityStreamSample]) -> String {
        let sorted = samples.sorted { $0.offsetSeconds < $1.offsetSeconds }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx creator="TezDav" version="1.1" xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"
             xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1">
          <metadata>
            <name>\(escapeXML(activity.name))</name>
            <time>\(isoFormatter.string(from: activity.startDate))</time>
          </metadata>
          <trk>
            <name>\(escapeXML(activity.name))</name>
            <type>\(activity.sportType)</type>
            <trkseg>
        """
        
        for sample in sorted {
            // A valid GPX trackpoint requires at least latitude and longitude.
            guard let lat = sample.latitude, let lon = sample.longitude else { continue }
            
            let timeAtOffset = activity.startDate.addingTimeInterval(TimeInterval(sample.offsetSeconds))
            let timeStr = isoFormatter.string(from: timeAtOffset)
            
            xml += "\n      <trkpt lat=\"\(lat)\" lon=\"\(lon)\">"
            
            if let alt = sample.altitude {
                xml += "\n        <ele>\(alt)</ele>"
            }
            
            xml += "\n        <time>\(timeStr)</time>"
            
            // Check if we have sensor data to add as extensions
            if sample.heartRate != nil || sample.cadence != nil || sample.power != nil {
                xml += "\n        <extensions>\n          <gpxtpx:TrackPointExtension>"
                if let hr = sample.heartRate {
                    xml += "\n            <gpxtpx:hr>\(Int(hr))</gpxtpx:hr>"
                }
                if let cad = sample.cadence {
                    xml += "\n            <gpxtpx:cad>\(Int(cad))</gpxtpx:cad>"
                }
                // Custom Garmin extension tags for power are supported by runalyze/intervals.icu
                if let power = sample.power {
                    xml += "\n            <gpxtpx:power>\(Int(power))</gpxtpx:power>"
                }
                xml += "\n          </gpxtpx:TrackPointExtension>\n        </extensions>"
            }
            
            xml += "\n      </trkpt>"
        }
        
        xml += """
        
            </trkseg>
          </trk>
        </gpx>
        """
        
        return xml
    }
    
    /// Formats a saved route as a standard GPX 1.1 file string with metadata and tracks.
    static func exportRouteToGPX(route: SavedRoute) -> String {
        let waypoints = route.waypoints
        let coords = route.routeCoordinates
        
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx creator="TezDav" version="1.1" xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(escapeXML(route.name))</name>
            <time>\(ISO8601DateFormatter().string(from: route.createdAt))</time>
          </metadata>
        """
        
        if !waypoints.isEmpty {
            xml += "\n  <rte>\n    <name>\(escapeXML(route.name))</name>"
            for pt in waypoints {
                xml += "\n    <rtept lat=\"\(pt.latitude)\" lon=\"\(pt.longitude)\" />"
            }
            xml += "\n  </rte>"
        }
        
        if !coords.isEmpty {
            xml += """
            
              <trk>
                <name>\(escapeXML(route.name))</name>
                <type>\(route.sportType)</type>
                <trkseg>
            """
            for pt in coords {
                xml += "\n      <trkpt lat=\"\(pt.latitude)\" lon=\"\(pt.longitude)\" />"
            }
            xml += """
            
                </trkseg>
              </trk>
            """
        }
        
        xml += "\n</gpx>\n"
        return xml
    }
    
    /// Generates a CSV string representing all activities in the given date range.
    static func exportToCSV(activities: [Activity]) -> String {
        var csv = "Date,SportType,Name,DistanceMeters,DurationSeconds,ElevationGainMeters,AvgHeartRate,AvgPower,TRIMP,TrainingLoad\n"
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        
        for act in activities {
            let dateStr = isoFormatter.string(from: act.startDate)
            let nameEscaped = "\"\(act.name.replacingOccurrences(of: "\"", with: "\"\""))\""
            let sport = act.sportType
            let dist = String(format: "%.1f", act.distanceMeters)
            let duration = String(format: "%.0f", act.movingTime)
            let elev = String(format: "%.1f", act.elevationGain)
            let hr = act.averageHeartRate != nil ? String(format: "%.1f", act.averageHeartRate!) : ""
            let powValue = act.averagePower != nil ? String(format: "%.1f", act.averagePower!) : ""
            let trimp = String(format: "%.1f", act.trimp)
            let load = String(format: "%.1f", act.trainingLoad)
            
            csv += "\(dateStr),\(sport),\(nameEscaped),\(dist),\(duration),\(elev),\(hr),\(powValue),\(trimp),\(load)\n"
        }
        
        return csv
    }
    
    /// Generates a CSV stream representing second-by-second activity telemetry.
    static func exportStreamToCSV(activity: Activity, samples: [ActivityStreamSample]) -> String {
        var csv = "TimeOffsetSeconds,DistanceMeters,Latitude,Longitude,HeartRateBPM,CadenceRPM,PowerWatts,SpeedMPS,AltitudeMeters\n"
        
        let sorted = samples.sorted { $0.offsetSeconds < $1.offsetSeconds }
        for sample in sorted {
            let offset = "\(sample.offsetSeconds)"
            let dist = sample.distanceMeters != nil ? String(format: "%.1f", sample.distanceMeters!) : ""
            let lat = sample.latitude != nil ? "\(sample.latitude!)" : ""
            let lon = sample.longitude != nil ? "\(sample.longitude!)" : ""
            let hr = sample.heartRate != nil ? String(format: "%.0f", sample.heartRate!) : ""
            let cad = sample.cadence != nil ? String(format: "%.0f", sample.cadence!) : ""
            let powValue = sample.power != nil ? String(format: "%.0f", sample.power!) : ""
            let speed = sample.speed != nil ? String(format: "%.2f", sample.speed!) : ""
            let alt = sample.altitude != nil ? String(format: "%.1f", sample.altitude!) : ""
            
            csv += "\(offset),\(dist),\(lat),\(lon),\(hr),\(cad),\(powValue),\(speed),\(alt)\n"
        }
        
        return csv
    }
    
    /// Compiles a full JSON archive database dump from SwiftData entities.
    static func exportToJSONBackup(
        activities: [Activity],
        settings: [UserSettings],
        weeks: [TrainingWeek],
        segments: [IntervalSegment]
    ) -> String {
        let formatter = ISO8601DateFormatter()
        
        var backupDict: [String: Any] = [:]
        
        // 1. Serialize Activities
        var actList: [[String: Any]] = []
        for act in activities {
            var actDict: [String: Any] = [
                "stravaId": act.stravaId,
                "sportType": act.sportType,
                "name": act.name,
                "startDate": formatter.string(from: act.startDate),
                "distanceMeters": act.distanceMeters,
                "movingTime": act.movingTime,
                "elapsedTime": act.elapsedTime,
                "elevationGain": act.elevationGain,
                "trimp": act.trimp,
                "trainingLoad": act.trainingLoad,
                "streamsImported": act.streamsImported
            ]
            if let hr = act.averageHeartRate { actDict["averageHeartRate"] = hr }
            if let powVal = act.averagePower { actDict["averagePower"] = powVal }
            if let cad = act.averageCadence { actDict["averageCadence"] = cad }
            if let spd = act.averageSpeed { actDict["averageSpeed"] = spd }
            if let poly = act.encodedPolyline { actDict["encodedPolyline"] = poly }
            
            // Personal Records
            if let v = act.best1kTime { actDict["best1kTime"] = v }
            if let v = act.best5kTime { actDict["best5kTime"] = v }
            if let v = act.best10kTime { actDict["best10kTime"] = v }
            if let v = act.bestHalfMarathonTime { actDict["bestHalfMarathonTime"] = v }
            if let v = act.bestMarathonTime { actDict["bestMarathonTime"] = v }
            if let v = act.peakPower5s { actDict["peakPower5s"] = v }
            if let v = act.peakPower1m { actDict["peakPower1m"] = v }
            if let v = act.peakPower5m { actDict["peakPower5m"] = v }
            if let v = act.peakPower20m { actDict["peakPower20m"] = v }
            if let v = act.peakPower60m { actDict["peakPower60m"] = v }
            
            actList.append(actDict)
        }
        backupDict["activities"] = actList
        
        // 2. Serialize UserSettings
        var setList: [[String: Any]] = []
        for set in settings {
            var setDict: [String: Any] = [
                "maxHeartRate": set.maxHeartRate,
                "restingHeartRate": set.restingHeartRate,
                "weightKg": set.weightKg,
                "mainSport": set.mainSport,
                "isHeartRateZonesAutomatic": set.isHeartRateZonesAutomatic,
                "hrZone1Max": set.hrZone1Max,
                "hrZone2Max": set.hrZone2Max,
                "hrZone3Max": set.hrZone3Max,
                "hrZone4Max": set.hrZone4Max,
                "lthrPaceSecondsPerKm": set.lthrPaceSecondsPerKm,
                "runningFTP": set.runningFTP,
                "cyclingFTP": set.cyclingFTP,
                "targetWeeklyDistanceMeters": set.targetWeeklyDistanceMeters,
                "weeklyCyclingGoalHours": set.weeklyCyclingGoalHours
            ]
            if let bDate = set.birthDate { setDict["birthDate"] = formatter.string(from: bDate) }
            if let rDate = set.raceDate { setDict["raceDate"] = formatter.string(from: rDate) }
            if let rDist = set.raceDistanceMeters { setDict["raceDistanceMeters"] = rDist }
            if let bikeW = set.bikeWeightKg { setDict["bikeWeightKg"] = bikeW }
            if let acc = set.stravaAccountName { setDict["stravaAccountName"] = acc }
            
            setList.append(setDict)
        }
        backupDict["settings"] = setList
        
        // 3. Serialize TrainingWeek planner
        var weekList: [[String: Any]] = []
        for week in weeks {
            let weekDict: [String: Any] = [
                "id": week.id,
                "startDate": formatter.string(from: week.startDate),
                "typeString": week.typeString,
                "targetVolumeMeters": week.targetVolumeMeters,
                "targetCyclingHours": week.targetCyclingHours
            ]
            weekList.append(weekDict)
        }
        backupDict["weeks"] = weekList
        
        // 4. Serialize IntervalSegments
        var segList: [[String: Any]] = []
        for seg in segments {
            var segDict: [String: Any] = [
                "activityId": seg.activityId,
                "segmentIndex": seg.segmentIndex,
                "type": seg.type,
                "startDistanceMeters": seg.startDistanceMeters,
                "endDistanceMeters": seg.endDistanceMeters,
                "duration": seg.duration,
                "averageSpeed": seg.averageSpeed
            ]
            if let hr = seg.averageHeartRate { segDict["averageHeartRate"] = hr }
            if let powVal = seg.averagePower { segDict["averagePower"] = powVal }
            
            segList.append(segDict)
        }
        backupDict["intervals"] = segList
        
        // Convert dictionary to JSON string
        if let data = try? JSONSerialization.data(withJSONObject: backupDict, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        
        return "{}"
    }
    
    // MARK: - Utility
    
    private static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
