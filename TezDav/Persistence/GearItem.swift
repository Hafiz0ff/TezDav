import Foundation
import SwiftData

@Model
final class GearItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var sportType: String              // "Run" or "Ride"
    var gearType: String               // "shoes", "bike", "chain", "pads"
    var brand: String?
    var startDate: Date
    var maxDistanceKm: Double
    var currentDistanceKm: Double
    var isActive: Bool
    var stravaGearId: String?
    
    @Relationship(deleteRule: .nullify, inverse: \Activity.gearItem)
    var activities: [Activity] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        sportType: String,
        gearType: String,
        brand: String? = nil,
        startDate: Date = Date(),
        maxDistanceKm: Double = 700.0,
        currentDistanceKm: Double = 0.0,
        isActive: Bool = true,
        stravaGearId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sportType = sportType
        self.gearType = gearType
        self.brand = brand
        self.startDate = startDate
        self.maxDistanceKm = maxDistanceKm
        self.currentDistanceKm = currentDistanceKm
        self.isActive = isActive
        self.stravaGearId = stravaGearId
    }
}
