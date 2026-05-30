import Foundation
import SwiftData

final class AchievementManager {
    static let shared = AchievementManager()
    
    private init() {}
    
    struct BadgeDefinition {
        let type: String
        let title: String
        let description: String
        let checker: ([Activity], UserSettings) -> (earned: Bool, date: Date?, activityId: Int64?)
    }
    
    let badges: [BadgeDefinition] = [
        BadgeDefinition(
            type: "first_steps",
            title: "Первые шаги",
            description: "Пройти более 5,000 шагов за одну тренировку",
            checker: { activities, _ in
                if let act = activities.first(where: { ($0.stepsCount ?? 0) >= 5000 }) {
                    return (true, act.startDate, act.stravaId)
                }
                return (false, nil, nil)
            }
        ),
        BadgeDefinition(
            type: "step_master",
            title: "Шагоман",
            description: "Пройти более 10,000 шагов за одну тренировку",
            checker: { activities, _ in
                if let act = activities.first(where: { ($0.stepsCount ?? 0) >= 10000 }) {
                    return (true, act.startDate, act.stravaId)
                }
                return (false, nil, nil)
            }
        ),
        BadgeDefinition(
            type: "mountain_goat",
            title: "Горный козёл",
            description: "Набрать более 500м высоты или достичь высоты 1,000м в походе/ходьбе",
            checker: { activities, _ in
                if let act = activities.first(where: {
                    let isWalkOrHike = $0.sportType.lowercased().contains("walk") || $0.sportType.lowercased().contains("hike")
                    return isWalkOrHike && ($0.elevationGain >= 500.0 || ($0.maxAltitude ?? 0.0) >= 1000.0)
                }) {
                    return (true, act.startDate, act.stravaId)
                }
                return (false, nil, nil)
            }
        ),
        BadgeDefinition(
            type: "streak_7d",
            title: "Неделя в тонусе",
            description: "Тренироваться каждый день в течение 7 дней подряд",
            checker: { activities, _ in
                let calendar = Calendar.current
                let activeDays = Set(activities.map { calendar.startOfDay(for: $0.startDate) }).sorted()
                guard activeDays.count >= 7 else { return (false, nil, nil) }
                
                var currentStreak = 1
                for i in 1..<activeDays.count {
                    let prev = activeDays[i-1]
                    let curr = activeDays[i]
                    let diff = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
                    if diff == 1 {
                        currentStreak += 1
                        if currentStreak >= 7 {
                            return (true, curr, nil) // Earned on the 7th day
                        }
                    } else if diff > 1 {
                        currentStreak = 1
                    }
                }
                return (false, nil, nil)
            }
        ),
        BadgeDefinition(
            type: "marathoner",
            title: "Марафонец",
            description: "Пробежать марафонскую дистанцию (42.2 км или более)",
            checker: { activities, _ in
                if let act = activities.first(where: {
                    $0.sportType.lowercased().contains("run") && $0.distanceMeters >= 42195.0
                }) {
                    return (true, act.startDate, act.stravaId)
                }
                return (false, nil, nil)
            }
        ),
        BadgeDefinition(
            type: "speedy_mile",
            title: "Быстрая миля",
            description: "Пробежать 1 км быстрее чем за 4 минуты (темп < 4:00/км)",
            checker: { activities, _ in
                if let act = activities.first(where: {
                    $0.sportType.lowercased().contains("run") && ($0.best1kTime ?? 9999.0) <= 240.0
                }) {
                    return (true, act.startDate, act.stravaId)
                }
                return (false, nil, nil)
            }
        ),
        BadgeDefinition(
            type: "road_knight",
            title: "Рыцарь дорог",
            description: "Проехать 100 км или более на велосипеде за одну поездку",
            checker: { activities, _ in
                if let act = activities.first(where: {
                    ($0.sportType.lowercased().contains("ride") || $0.sportType.lowercased().contains("cycl")) && $0.distanceMeters >= 100000.0
                }) {
                    return (true, act.startDate, act.stravaId)
                }
                return (false, nil, nil)
            }
        ),
        BadgeDefinition(
            type: "deep_diver",
            title: "Покоритель глубин",
            description: "Проплыть 1,000 метров или более",
            checker: { activities, _ in
                if let act = activities.first(where: {
                    $0.sportType.lowercased().contains("swim") && $0.distanceMeters >= 1000.0
                }) {
                    return (true, act.startDate, act.stravaId)
                }
                return (false, nil, nil)
            }
        ),
        BadgeDefinition(
            type: "casual_start",
            title: "Начало пути",
            description: "Выполнить первую тренировку в любительском (Casual) режиме",
            checker: { activities, settings in
                if settings.appMode == .casual, let act = activities.first {
                    return (true, act.startDate, act.stravaId)
                }
                return (false, nil, nil)
            }
        ),
        BadgeDefinition(
            type: "super_active",
            title: "Супер-активность",
            description: "Активная тренировка продолжительностью более 2 часов (120 минут)",
            checker: { activities, _ in
                if let act = activities.first(where: {
                    let mins = Double($0.activeMinutes ?? Int($0.movingTime / 60.0))
                    return mins >= 120.0
                }) {
                    return (true, act.startDate, act.stravaId)
                }
                return (false, nil, nil)
            }
        )
    ]
    
    @MainActor
    func scanAndAwardAchievements(context: ModelContext, activities: [Activity], settings: UserSettings) {
        // Fetch existing achievements
        let fetchDescriptor = FetchDescriptor<Achievement>()
        guard let existingAchievements = try? context.fetch(fetchDescriptor) else { return }
        let existingTypes = Set(existingAchievements.map { $0.type })
        
        var newAchievementsCount = 0
        for badge in badges {
            if existingTypes.contains(badge.type) { continue }
            
            let result = badge.checker(activities, settings)
            if result.earned {
                let achievement = Achievement(
                    type: badge.type,
                    dateEarned: result.date ?? Date(),
                    associatedActivityId: result.activityId,
                    title: badge.title,
                    descriptionText: badge.description
                )
                context.insert(achievement)
                newAchievementsCount += 1
            }
        }
        
        if newAchievementsCount > 0 {
            try? context.save()
        }
    }
}
