import AppIntents
import SwiftData
import Foundation
import UIKit

// MARK: - AppShortcutsProvider
public struct TezDavShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetFormIntent(),
            phrases: [
                "Как моя форма в \(.applicationName)?",
                "Как я сейчас в \(.applicationName)?",
                "What is my status in \(.applicationName)?",
                "Am I ready to train in \(.applicationName)?"
            ],
            shortTitle: "Как я сейчас",
            systemImageName: "heart.text.square"
        )
        
        AppShortcut(
            intent: GetWeeklyStatsIntent(),
            phrases: [
                "Моя форма за неделю в \(.applicationName)",
                "Weekly volume in \(.applicationName)",
                "Недельная статистика в \(.applicationName)"
            ],
            shortTitle: "Моя форма за неделю",
            systemImageName: "calendar"
        )
        
        AppShortcut(
            intent: GetLastWorkoutIntent(),
            phrases: [
                "Последняя тренировка в \(.applicationName)",
                "Show last workout in \(.applicationName)",
                "Моя последняя активность в \(.applicationName)"
            ],
            shortTitle: "Последняя тренировка",
            systemImageName: "figure.run"
        )
        
        AppShortcut(
            intent: GetGearWearIntent(),
            phrases: [
                "Когда менять кроссовки в \(.applicationName)?",
                "Check shoe wear in \(.applicationName)",
                "Износ экипировки в \(.applicationName)"
            ],
            shortTitle: "Когда меняй кроссовки",
            systemImageName: "shoeprints.fill"
        )
        
        AppShortcut(
            intent: ImportWorkoutIntent(),
            phrases: [
                "Добавить тренировку в \(.applicationName)",
                "Import workout in \(.applicationName)",
                "Загрузить файл тренировки в \(.applicationName)"
            ],
            shortTitle: "Добавить тренировку",
            systemImageName: "plus.circle"
        )
    }
}

// MARK: - AppIntents

public struct GetFormIntent: AppIntent {
    public static var title: LocalizedStringResource = "Как я сейчас?"
    public static var description = IntentDescription("Показывает утренний индекс готовности, TSB и рекомендацию тренера.")
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let container = TezDavApp.modelContainer
        let context = ModelContext(container)
        
        let actDescriptor = FetchDescriptor<Activity>()
        let activities = (try? context.fetch(actDescriptor)) ?? []
        
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let settings = (try? context.fetch(settingsDescriptor))?.first ?? UserSettings()
        
        let gearDescriptor = FetchDescriptor<GearItem>()
        let gears = (try? context.fetch(gearDescriptor)) ?? []
        
        let isRu = Locale.current.identifier.hasPrefix("ru")
        
        let summary = DashboardViewModel.summary(from: activities)
        let tsb = summary.tsb
        
        // Fetch HRV and sleep from HealthKitManager simulator calculations
        let hrvToday = settings.lastMorningHrv
        let hrvBaseline = settings.lastMorningHrv ?? 55.0
        let sleepHours = 7.5
        let recoveryScore = HealthKitManager.shared.calculateRecoveryScore(
            hrvToday: hrvToday,
            hrvBaseline: hrvBaseline,
            sleepHours: sleepHours,
            restingHR: 60.0,
            tsb: tsb
        )
        
        let insights = CoachingEngine.generateInsights(activities: activities, settings: settings, gears: gears)
        let advice = insights.first
        
        let adviceText = isRu ? 
            (advice?.messageRu ?? "Все показатели в норме. Хорошего дня!") : 
            (advice?.messageEn ?? "All systems operational. Have a great day!")
        
        let value = isRu ?
            "Готовность: \(recoveryScore)%. Форма (TSB): \(Int(tsb)). Рекомендация: \(adviceText)" :
            "Readiness Score is \(recoveryScore)%. Freshness (TSB) is \(Int(tsb)). Coaching advice: \(adviceText)"
            
        let dialogValue = isRu ?
            "Ваша готовность составляет \(recoveryScore) процентов. Баланс тренировочной формы \(Int(tsb)). Тренер советует: \(adviceText)" :
            "Your training readiness is \(recoveryScore) percent. Weekly freshness TSB is \(Int(tsb)). Daily coach recommendation is: \(adviceText)"
            
        return .result(value: value, dialog: IntentDialog(LocalizedStringResource(stringLiteral: dialogValue)))
    }
}

public struct GetWeeklyStatsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Моя форма за неделю"
    public static var description = IntentDescription("Показывает дистанцию и количество тренировок за последние 7 дней.")
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let container = TezDavApp.modelContainer
        let context = ModelContext(container)
        
        let actDescriptor = FetchDescriptor<Activity>()
        let activities = (try? context.fetch(actDescriptor)) ?? []
        
        let isRu = Locale.current.identifier.hasPrefix("ru")
        let calendar = Calendar.current
        
        let now = Date()
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now.addingTimeInterval(-7 * 86400)
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart) ?? thisWeekStart.addingTimeInterval(-7 * 86400)
        
        let thisWeekActs = activities.filter { $0.startDate >= thisWeekStart && $0.startDate <= now }
        let lastWeekActs = activities.filter { $0.startDate >= lastWeekStart && $0.startDate < thisWeekStart }
        
        let thisWeekDistKm = thisWeekActs.reduce(0.0) { $0 + $1.distanceMeters } / 1000.0
        let lastWeekDistKm = lastWeekActs.reduce(0.0) { $0 + $1.distanceMeters } / 1000.0
        
        var comparisonText = ""
        if lastWeekDistKm > 0 {
            let diff = ((thisWeekDistKm - lastWeekDistKm) / lastWeekDistKm) * 100.0
            comparisonText = isRu ? 
                String(format: " (%+d%% к прошлой неделе)", Int(diff)) :
                String(format: " (%+d%% vs last week)", Int(diff))
        }
        
        let value = isRu ?
            "На этой неделе: \(thisWeekActs.count) тренировок, \(String(format: "%.1f", thisWeekDistKm)) км\(comparisonText)." :
            "This week: \(thisWeekActs.count) workouts, \(String(format: "%.1f", thisWeekDistKm)) km\(comparisonText)."
            
        let dialogValue = isRu ?
            "За текущую неделю вы выполнили \(thisWeekActs.count) тренировок, набегав и накатав в сумме \(String(format: "%.1f", thisWeekDistKm)) километров\(comparisonText)." :
            "This week you recorded \(thisWeekActs.count) activities, totaling \(String(format: "%.1f", thisWeekDistKm)) kilometers\(comparisonText)."
            
        return .result(value: value, dialog: IntentDialog(LocalizedStringResource(stringLiteral: dialogValue)))
    }
}

public struct GetLastWorkoutIntent: AppIntent {
    public static var title: LocalizedStringResource = "Последняя тренировка"
    public static var description = IntentDescription("Показывает показатели последней записанной активности.")
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let container = TezDavApp.modelContainer
        let context = ModelContext(container)
        
        let actDescriptor = FetchDescriptor<Activity>()
        let activities = (try? context.fetch(actDescriptor)) ?? []
        
        let isRu = Locale.current.identifier.hasPrefix("ru")
        
        guard let lastAct = activities.sorted(by: { $0.startDate > $1.startDate }).first else {
            let text = isRu ? "У вас еще нет записанных тренировок." : "You don't have any recorded activities yet."
            return .result(value: text, dialog: IntentDialog(LocalizedStringResource(stringLiteral: text)))
        }
        
        let distKm = lastAct.distanceMeters / 1000.0
        let hours = Int(lastAct.movingTime) / 3600
        let minutes = (Int(lastAct.movingTime) % 3600) / 60
        
        let sportName = isRu ? 
            (lastAct.sportType.lowercased() == "run" ? "Бег" : "Заезд") : 
            lastAct.sportType
            
        let value = isRu ?
            "Последний \(sportName) '\(lastAct.name)': \(String(format: "%.1f", distKm)) км за \(hours)ч \(minutes)мин." :
            "Latest \(sportName) '\(lastAct.name)': \(String(format: "%.1f", distKm)) km in \(hours)h \(minutes)m."
            
        let dialogValue = isRu ?
            "Ваша последняя тренировка — это \(sportName) \(lastAct.name). Дистанция составила \(String(format: "%.1f", distKm)) километров за \(hours) часов и \(minutes) минут." :
            "Your latest activity was a \(sportName) named \(lastAct.name). Covering \(String(format: "%.1f", distKm)) kilometers in \(hours) hours and \(minutes) minutes."
            
        return .result(value: value, dialog: IntentDialog(LocalizedStringResource(stringLiteral: dialogValue)))
    }
}

public struct GetGearWearIntent: AppIntent {
    public static var title: LocalizedStringResource = "Когда менять кроссовки?"
    public static var description = IntentDescription("Показывает пробег и оставшийся ресурс активных пар кроссовок.")
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let container = TezDavApp.modelContainer
        let context = ModelContext(container)
        
        let gearDescriptor = FetchDescriptor<GearItem>()
        let gears = (try? context.fetch(gearDescriptor)) ?? []
        
        let isRu = Locale.current.identifier.hasPrefix("ru")
        
        let activeShoes = gears.filter { $0.isActive && $0.sportType == "Run" }
        
        guard let shoe = activeShoes.sorted(by: { $0.currentDistanceKm > $1.currentDistanceKm }).first else {
            let text = isRu ? "Активные беговые кроссовки не найдены в профиле." : "No active running shoes found in your profile."
            return .result(value: text, dialog: IntentDialog(LocalizedStringResource(stringLiteral: text)))
        }
        
        let limit = shoe.maxDistanceKm
        let remaining = limit - shoe.currentDistanceKm
        let wearPct = (shoe.currentDistanceKm / limit) * 100.0
        
        let value = isRu ?
            "\(shoe.name): пробег \(Int(shoe.currentDistanceKm))/\(Int(limit)) км. Износ \(Int(wearPct))%. Осталось \(Int(max(0, remaining))) км." :
            "\(shoe.name): mileage \(Int(shoe.currentDistanceKm))/\(Int(limit)) km. Wear \(Int(wearPct))%. \(Int(max(0, remaining))) km remaining."
            
        let dialogValue = isRu ?
            "Беговые кроссовки \(shoe.name) имеют пробег \(Int(shoe.currentDistanceKm)) километров из максимальных \(Int(limit)). Текущий износ \(Int(wearPct)) процентов, осталось \(Int(max(0, remaining))) километров." :
            "Your running shoes \(shoe.name) have a mileage of \(Int(shoe.currentDistanceKm)) kilometers out of a \(Int(limit)) maximum limit. This represents \(Int(wearPct)) percent wear, leaving \(Int(max(0, remaining))) kilometers remaining."
            
        return .result(value: value, dialog: IntentDialog(LocalizedStringResource(stringLiteral: dialogValue)))
    }
}

public struct ImportWorkoutIntent: AppIntent {
    public static var title: LocalizedStringResource = "Добавить тренировку"
    public static var description = IntentDescription("Открывает TezDav на вкладке импорта файлов тренировок.")
    public static var openAppWhenRun: Bool = true
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        // Deep link redirection URL that our app root view parses
        if let url = URL(string: "tezdav://import") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}
