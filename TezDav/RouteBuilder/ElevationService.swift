import Foundation
import CoreLocation

final class ElevationService {
    struct OpenElevationRequest: Codable {
        struct Location: Codable {
            let latitude: Double
            let longitude: Double
        }
        let locations: [Location]
    }
    
    struct OpenElevationResponse: Codable {
        struct Result: Codable {
            let latitude: Double
            let longitude: Double
            let elevation: Double
        }
        let results: [Result]
    }
    
    /// Fetches the elevation profile for a series of coordinates.
    /// If the API fails, is slow, or offline, it falls back to a mock elevation profile.
    static func fetchElevationProfile(for coordinates: [CLLocationCoordinate2D]) async -> [ElevationPoint] {
        guard !coordinates.isEmpty else { return [] }
        
        // 1. Calculate cumulative distances
        var pointsWithDistance: [(coord: CLLocationCoordinate2D, distance: Double)] = []
        var totalDist = 0.0
        pointsWithDistance.append((coordinates[0], 0.0))
        
        for i in 1..<coordinates.count {
            let prev = coordinates[i - 1]
            let curr = coordinates[i]
            let loc1 = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
            let loc2 = CLLocation(latitude: curr.latitude, longitude: curr.longitude)
            totalDist += loc1.distance(from: loc2)
            pointsWithDistance.append((curr, totalDist))
        }
        
        // 2. Sample coordinates to avoid huge API requests (max 40 points)
        let maxSamples = 40
        var sampledPoints: [(coord: CLLocationCoordinate2D, distance: Double)] = []
        if pointsWithDistance.count <= maxSamples {
            sampledPoints = pointsWithDistance
        } else {
            sampledPoints.append(pointsWithDistance[0])
            let step = Double(pointsWithDistance.count - 1) / Double(maxSamples - 1)
            for i in 1..<(maxSamples - 1) {
                let idx = Int(round(Double(i) * step))
                if idx < pointsWithDistance.count {
                    sampledPoints.append(pointsWithDistance[idx])
                }
            }
            sampledPoints.append(pointsWithDistance.last!)
        }
        
        // 3. Request Open Elevation API
        let requestLocations = sampledPoints.map {
            OpenElevationRequest.Location(latitude: $0.coord.latitude, longitude: $0.coord.longitude)
        }
        let reqBody = OpenElevationRequest(locations: requestLocations)
        
        guard let url = URL(string: "https://api.open-elevation.com/api/v1/lookup") else {
            return generateFallbackProfile(sampledPoints: sampledPoints, totalDist: totalDist)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(reqBody)
            request.timeoutInterval = 8.0 // 8s timeout
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return generateFallbackProfile(sampledPoints: sampledPoints, totalDist: totalDist)
            }
            
            let decoded = try JSONDecoder().decode(OpenElevationResponse.self, from: data)
            
            // Map results back to distances
            var profile: [ElevationPoint] = []
            for i in 0..<sampledPoints.count {
                guard i < decoded.results.count else { break }
                let dist = sampledPoints[i].distance
                let elev = decoded.results[i].elevation
                profile.append(ElevationPoint(distance: dist, elevation: elev))
            }
            return profile
        } catch {
            print("Elevation API failed: \(error.localizedDescription). Using fallback profile.")
            return generateFallbackProfile(sampledPoints: sampledPoints, totalDist: totalDist)
        }
    }
    
    private static func generateFallbackProfile(sampledPoints: [(coord: CLLocationCoordinate2D, distance: Double)], totalDist: Double) -> [ElevationPoint] {
        var profile: [ElevationPoint] = []
        let baseElev = 150.0 // meters
        for pt in sampledPoints {
            let progress = pt.distance / (totalDist > 0 ? totalDist : 1.0)
            let wave = sin(progress * .pi * 3) * 25.0 // +/- 25m hills
            profile.append(ElevationPoint(distance: pt.distance, elevation: baseElev + wave))
        }
        return profile
    }
}
