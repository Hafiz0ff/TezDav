import Foundation
import SwiftData
import CoreLocation

@Model
final class PersonalSegment {
    @Attribute(.unique) var id: UUID
    var name: String
    var sportType: String              // "Run" or "Ride"
    var distanceMeters: Double
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double
    var endLongitude: Double
    
    // Coordinates data encoded (just like Segment)
    var coordinatesData: Data
    
    @Relationship(deleteRule: .cascade, inverse: \SegmentEffort.personalSegment)
    var efforts: [SegmentEffort] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        sportType: String,
        distanceMeters: Double,
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double,
        coordinatesData: Data = Data()
    ) {
        self.id = id
        self.name = name
        self.sportType = sportType
        self.distanceMeters = distanceMeters
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.coordinatesData = coordinatesData
    }
}

extension PersonalSegment {
    var coordinates: [CLLocationCoordinate2D] {
        get {
            guard let decoded = try? JSONDecoder().decode([CodableCoordinate].self, from: coordinatesData) else {
                return []
            }
            return decoded.map { $0.coordinate2D }
        }
        set {
            let encoded = newValue.map { CodableCoordinate($0) }
            if let data = try? JSONEncoder().encode(encoded) {
                coordinatesData = data
            }
        }
    }
}
