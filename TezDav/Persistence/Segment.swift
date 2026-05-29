import Foundation
import SwiftData
import CoreLocation

@Model
final class Segment {
    @Attribute(.unique) var id: UUID
    var name: String
    var sportType: String              // "Run" или "Ride"
    var distanceMeters: Double
    var averageGrade: Double           // Средний уклон в %
    var elevationGain: Double          // Набор высоты в метрах
    
    // Координаты старта и финиша
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double
    var endLongitude: Double
    
    // Данные координат трека (для отображения на карте)
    var coordinatesData: Data
    
    // Отношение «один-ко-многим» с попытками
    @Relationship(deleteRule: .cascade, inverse: \SegmentEffort.segment)
    var efforts: [SegmentEffort] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        sportType: String,
        distanceMeters: Double,
        averageGrade: Double,
        elevationGain: Double,
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
        self.averageGrade = averageGrade
        self.elevationGain = elevationGain
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.coordinatesData = coordinatesData
    }
}

extension Segment {
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
