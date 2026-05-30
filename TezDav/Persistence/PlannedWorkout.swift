import Foundation
import SwiftData

@Model
final class PlannedWorkout {
    @Attribute(.unique) var id: UUID
    var date: Date
    var sportType: String // "Run", "Ride", "Walk", "Swim"
    var title: String
    var plannedDurationSeconds: Double
    var plannedDistanceMeters: Double
    var plannedTSS: Double
    var isCompleted: Bool
    
    init(
        id: UUID = UUID(),
        date: Date,
        sportType: String,
        title: String,
        plannedDurationSeconds: Double,
        plannedDistanceMeters: Double,
        plannedTSS: Double,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.date = date
        self.sportType = sportType
        self.title = title
        self.plannedDurationSeconds = plannedDurationSeconds
        self.plannedDistanceMeters = plannedDistanceMeters
        self.plannedTSS = plannedTSS
        self.isCompleted = isCompleted
    }
}
