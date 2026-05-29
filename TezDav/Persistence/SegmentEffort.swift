import Foundation
import SwiftData

@Model
final class SegmentEffort {
    @Attribute(.unique) var id: UUID
    var activityId: Int64?             // Ссылка на активность пользователя (nil для виртуальных соперников)
    var activityName: String?          // Название тренировки
    var athleteName: String            // Имя спортсмена ("Вы" или имя бота)
    var startDate: Date
    var elapsedTime: TimeInterval      // Время прохождения в секундах
    var averageHeartRate: Double?
    var averagePower: Double?
    var averageSpeed: Double?          // в м/с
    var isMock: Bool                   // Флаг виртуального соперника
    
    var segment: Segment?
    
    init(
        id: UUID = UUID(),
        activityId: Int64? = nil,
        activityName: String? = nil,
        athleteName: String,
        startDate: Date,
        elapsedTime: TimeInterval,
        averageHeartRate: Double? = nil,
        averagePower: Double? = nil,
        averageSpeed: Double? = nil,
        isMock: Bool = false
    ) {
        self.id = id
        self.activityId = activityId
        self.activityName = activityName
        self.athleteName = athleteName
        self.startDate = startDate
        self.elapsedTime = elapsedTime
        self.averageHeartRate = averageHeartRate
        self.averagePower = averagePower
        self.averageSpeed = averageSpeed
        self.isMock = isMock
    }
}
