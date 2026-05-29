import Foundation
import SwiftData
import CoreLocation

struct CodableCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(_ coord: CLLocationCoordinate2D) {
        self.latitude = coord.latitude
        self.longitude = coord.longitude
    }
    
    var coordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct ElevationPoint: Codable, Identifiable {
    var id: UUID { UUID() } // for Chart iteration
    let distance: Double // meters
    let elevation: Double // meters
}

@Model
final class SavedRoute {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var sportType: String              // "Run" or "Ride"
    var totalDistanceMeters: Double
    var totalElevationGain: Double
    var totalElevationLoss: Double
    var estimatedTimeSeconds: Double
    
    var waypointsData: Data
    var routeCoordinatesData: Data
    var elevationProfileData: Data?
    
    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        sportType: String = "Run",
        totalDistanceMeters: Double = 0.0,
        totalElevationGain: Double = 0.0,
        totalElevationLoss: Double = 0.0,
        estimatedTimeSeconds: Double = 0.0,
        waypointsData: Data = Data(),
        routeCoordinatesData: Data = Data(),
        elevationProfileData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sportType = sportType
        self.totalDistanceMeters = totalDistanceMeters
        self.totalElevationGain = totalElevationGain
        self.totalElevationLoss = totalElevationLoss
        self.estimatedTimeSeconds = estimatedTimeSeconds
        self.waypointsData = waypointsData
        self.routeCoordinatesData = routeCoordinatesData
        self.elevationProfileData = elevationProfileData
    }
}

extension SavedRoute {
    var waypoints: [CLLocationCoordinate2D] {
        get {
            guard let decoded = try? JSONDecoder().decode([CodableCoordinate].self, from: waypointsData) else {
                return []
            }
            return decoded.map { $0.coordinate2D }
        }
        set {
            let encoded = newValue.map { CodableCoordinate($0) }
            if let data = try? JSONEncoder().encode(encoded) {
                waypointsData = data
            }
        }
    }
    
    var routeCoordinates: [CLLocationCoordinate2D] {
        get {
            guard let decoded = try? JSONDecoder().decode([CodableCoordinate].self, from: routeCoordinatesData) else {
                return []
            }
            return decoded.map { $0.coordinate2D }
        }
        set {
            let encoded = newValue.map { CodableCoordinate($0) }
            if let data = try? JSONEncoder().encode(encoded) {
                routeCoordinatesData = data
            }
        }
    }
    
    var elevationProfile: [ElevationPoint] {
        get {
            guard let data = elevationProfileData,
                  let decoded = try? JSONDecoder().decode([ElevationPoint].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                elevationProfileData = data
            }
        }
    }
}
