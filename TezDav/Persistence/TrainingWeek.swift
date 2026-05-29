import Foundation
import SwiftData

@Model
final class TrainingWeek {
    @Attribute(.unique) var id: String // week_YYYY_WW
    var startDate: Date
    var typeString: String // "Базовая" | "Развивающая" | "Ударная" | "Восстановительная" | "Подводящая"
    var targetVolumeMeters: Double
    var targetCyclingHours: Double
    
    init(
        id: String,
        startDate: Date,
        typeString: String,
        targetVolumeMeters: Double,
        targetCyclingHours: Double
    ) {
        self.id = id
        self.startDate = startDate
        self.typeString = typeString
        self.targetVolumeMeters = targetVolumeMeters
        self.targetCyclingHours = targetCyclingHours
    }
}
