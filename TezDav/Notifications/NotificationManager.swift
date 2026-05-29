import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    // Requests notification permission from UNUserNotificationCenter
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }
    
    // Check if permission is granted
    func isPermissionGranted() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    // Trigger 1: Check and notify if synced activities broke all-time personal records
    func checkAndNotifyNewRecords(activitiesSynced: [Activity], context: ModelContext) {
        let descriptor = FetchDescriptor<Activity>()
        guard let allActivities = try? context.fetch(descriptor) else { return }
        
        let center = UNUserNotificationCenter.current()
        
        for newAct in activitiesSynced {
            let isRunning = newAct.sportType.lowercased().contains("run")
            let isCycling = newAct.sportType.lowercased().contains("ride")
            
            if isRunning {
                let checkDistances: [(name: String, keyPath: ReferenceWritableKeyPath<Activity, TimeInterval?>)] = [
                    ("1 км", \Activity.best1kTime),
                    ("5 км", \Activity.best5kTime),
                    ("10 км", \Activity.best10kTime),
                    ("Полумарафон", \Activity.bestHalfMarathonTime),
                    ("Марафон", \Activity.bestMarathonTime)
                ]
                
                for distance in checkDistances {
                    if let newTime = newAct[keyPath: distance.keyPath] {
                        // Find if there was a previous best record
                        let olderBests = allActivities.filter { 
                            $0.stravaId != newAct.stravaId && 
                            $0.sportType.lowercased().contains("run") && 
                            $0[keyPath: distance.keyPath] != nil 
                        }
                        
                        let prevBestAct = olderBests.min(by: { $0[keyPath: distance.keyPath]! < $1[keyPath: distance.keyPath]! })
                        
                        if let prevBestAct = prevBestAct, let prevTime = prevBestAct[keyPath: distance.keyPath] {
                            if newTime < prevTime {
                                // Record is broken!
                                triggerRecordNotification(
                                    distance: distance.name,
                                    newValStr: formattedDuration(newTime),
                                    prevValStr: formattedDuration(prevTime),
                                    prevDate: prevBestAct.startDate,
                                    activityId: newAct.stravaId
                                )
                            }
                        } else if prevBestAct == nil {
                            // First record!
                            triggerRecordNotification(
                                distance: distance.name,
                                newValStr: formattedDuration(newTime),
                                prevValStr: nil,
                                prevDate: nil,
                                activityId: newAct.stravaId
                            )
                        }
                    }
                }
            } else if isCycling {
                let checkPowers: [(name: String, keyPath: ReferenceWritableKeyPath<Activity, Double?>)] = [
                    ("5 сек", \Activity.peakPower5s),
                    ("1 мин", \Activity.peakPower1m),
                    ("5 мин", \Activity.peakPower5m),
                    ("20 мин", \Activity.peakPower20m),
                    ("60 мин", \Activity.peakPower60m)
                ]
                
                for cp in checkPowers {
                    if let newPower = newAct[keyPath: cp.keyPath] {
                        let olderBests = allActivities.filter { 
                            $0.stravaId != newAct.stravaId && 
                            $0.sportType.lowercased().contains("ride") && 
                            $0[keyPath: cp.keyPath] != nil 
                        }
                        
                        let prevBestAct = olderBests.max(by: { $0[keyPath: cp.keyPath]! < $1[keyPath: cp.keyPath]! })
                        
                        if let prevBestAct = prevBestAct, let prevPower = prevBestAct[keyPath: cp.keyPath] {
                            if newPower > prevPower {
                                // CP Record is broken!
                                triggerPowerRecordNotification(
                                    duration: cp.name,
                                    newValStr: String(format: "%.0f Вт", newPower),
                                    prevValStr: String(format: "%.0f Вт", prevPower),
                                    prevDate: prevBestAct.startDate,
                                    activityId: newAct.stravaId
                                )
                            }
                        } else if prevBestAct == nil {
                            // First record!
                            triggerPowerRecordNotification(
                                duration: cp.name,
                                newValStr: String(format: "%.0f Вт", newPower),
                                prevValStr: nil,
                                prevDate: nil,
                                activityId: newAct.stravaId
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func triggerRecordNotification(distance: String, newValStr: String, prevValStr: String?, prevDate: Date?, activityId: Int64) {
        let content = UNMutableNotificationContent()
        content.title = "🏆 Новый личный рекорд!"
        content.sound = .default
        content.userInfo = ["activityId": activityId]
        
        if let prevValStr = prevValStr, let prevDate = prevDate {
            content.body = "Новый рекорд на \(distance) — \(newValStr). Предыдущий был \(prevValStr) \(timeAgoString(from: prevDate))."
        } else {
            content.body = "Зафиксирован первый личный рекорд на \(distance) — \(newValStr)!"
        }
        
        let request = UNNotificationRequest(identifier: "record-\(distance)-\(activityId)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func triggerPowerRecordNotification(duration: String, newValStr: String, prevValStr: String?, prevDate: Date?, activityId: Int64) {
        let content = UNMutableNotificationContent()
        content.title = "⚡️ Новый пик мощности!"
        content.sound = .default
        content.userInfo = ["activityId": activityId]
        
        if let prevValStr = prevValStr, let prevDate = prevDate {
            content.body = "Пиковая мощность за \(duration) увеличилась до \(newValStr). Предыдущий рекорд составлял \(prevValStr) \(timeAgoString(from: prevDate))."
        } else {
            content.body = "Зафиксирован первый рекорд мощности за \(duration) — \(newValStr)!"
        }
        
        let request = UNNotificationRequest(identifier: "power-\(duration)-\(activityId)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // Trigger 2: Check and notify if TSB drops below -25 (throttled once every 3 days)
    func checkTSBOverload(tsb: Double, settings: UserSettings, context: ModelContext) {
        guard tsb < -25 else { return }
        
        // Throttling check (once every 3 days)
        if let lastNotify = settings.lastTsbNotificationDate {
            let diffDays = Calendar.current.dateComponents([.day], from: lastNotify, to: .now).day ?? 0
            if diffDays < 3 {
                return
            }
        }
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Внимание: Высокая нагрузка"
        content.sound = .default
        content.body = String(format: "Высокая накопленная усталость. TSB = %.0f. Рекомендуется лёгкая тренировка или день отдыха.", tsb)
        
        let request = UNNotificationRequest(identifier: "tsb-overload", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        
        settings.lastTsbNotificationDate = .now
        try? context.save()
    }
    
    // Trigger 3: Schedule Weekly training report (runs Sunday at 20:00)
    func scheduleWeeklyReport(context: ModelContext) {
        let descriptor = FetchDescriptor<Activity>()
        guard let allActivities = try? context.fetch(descriptor) else { return }
        
        let calendar = Calendar.current
        let today = Date()
        
        // Find current week interval (Monday to Sunday)
        guard let currentWeekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return }
        let currentWeekStart = currentWeekInterval.start
        
        // Find previous week interval
        guard let prevWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) else { return }
        guard let prevWeekEnd = calendar.date(byAdding: .second, value: -1, to: currentWeekStart) else { return }
        
        // 1. Current week stats
        let thisWeekActs = allActivities.filter { $0.startDate >= currentWeekStart && $0.startDate <= today }
        let thisWeekDistKm = thisWeekActs.reduce(0.0) { $0 + $1.distanceMeters } / 1000.0
        let thisWeekDurationSec = thisWeekActs.reduce(0.0) { $0 + $1.movingTime }
        
        // 2. Previous week stats
        let prevWeekActs = allActivities.filter { $0.startDate >= prevWeekStart && $0.startDate <= prevWeekEnd }
        let prevWeekDistKm = prevWeekActs.reduce(0.0) { $0 + $1.distanceMeters } / 1000.0
        
        // Calculate difference percentage
        var percentageStr = ""
        if prevWeekDistKm > 0 {
            let diff = ((thisWeekDistKm - prevWeekDistKm) / prevWeekDistKm) * 100.0
            percentageStr = String(format: " (%+d%% к прошлой неделе)", Int(diff))
        }
        
        let content = UNMutableNotificationContent()
        content.title = "📊 Еженедельный отчет закрыт!"
        content.sound = .default
        
        let hours = Int(thisWeekDurationSec) / 3600
        let minutes = (Int(thisWeekDurationSec) % 3600) / 60
        content.body = String(
            format: "Неделя закрыта: %.0f км за %дч %дмин.%@.",
            thisWeekDistKm,
            hours,
            minutes,
            percentageStr
        )
        
        // Schedule calendar trigger for Sunday 20:00
        var components = DateComponents()
        components.weekday = 1 // Sunday in Gregorian Calendar (1 = Sunday, 2 = Monday, etc.)
        components.hour = 20
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly-report", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // Trigger 4: Goal progress check reminder (Thursday 09:00)
    func scheduleGoalReminder(settings: UserSettings, context: ModelContext) {
        let descriptor = FetchDescriptor<Activity>()
        guard let allActivities = try? context.fetch(descriptor) else { return }
        
        let targetRunning = settings.targetWeeklyDistanceMeters
        guard targetRunning > 0 else { return }
        
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return }
        let weekStart = weekInterval.start
        
        // Calculate completed distance this week
        let runningActsThisWeek = allActivities.filter { 
            $0.startDate >= weekStart && 
            $0.sportType.lowercased().contains("run") 
        }
        let completedMeters = runningActsThisWeek.reduce(0.0) { $0 + $1.distanceMeters }
        
        // Check if progress < 40%
        let progress = completedMeters / targetRunning
        guard progress < 0.40 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎯 Напоминание о недельной цели"
        content.sound = .default
        content.body = String(
            format: "До конца недели осталось 3 дня. Цель: %.0f км, выполнено: %.1f км.",
            targetRunning / 1000.0,
            completedMeters / 1000.0
        )
        
        // Schedule calendar trigger for Thursday 09:00
        var components = DateComponents()
        components.weekday = 5 // Thursday
        components.hour = 9
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "goal-reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // Trigger 5: Countdown to Target Race (14, 7, 3, 1 days before target race)
    func scheduleRaceCountdown(settings: UserSettings) {
        guard let raceDate = settings.raceDate else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["race-14", "race-7", "race-3", "race-1"])
            return
        }
        
        let calendar = Calendar.current
        let raceStartOfDay = calendar.startOfDay(for: raceDate)
        
        let countdownOffsets = [14, 7, 3, 1]
        for days in countdownOffsets {
            guard let triggerDate = calendar.date(byAdding: .day, value: -days, to: raceStartOfDay) else { continue }
            // Only schedule if trigger date is in the future
            guard triggerDate > Date() else { continue }
            
            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            
            let content = UNMutableNotificationContent()
            content.title = "🏃‍♂️ Приближается целевой старт!"
            content.sound = .default
            
            // Format days text
            let dayWord = days == 1 ? "день" : (days < 5 ? "дня" : "дней")
            content.body = "До старта осталось всего \(days) \(dayWord)! Текущая форма и свежесть готовы к финальной подводке."
            
            var scheduleComponents = DateComponents()
            scheduleComponents.year = triggerComponents.year
            scheduleComponents.month = triggerComponents.month
            scheduleComponents.day = triggerComponents.day
            scheduleComponents.hour = 10 // send in the morning at 10 AM
            scheduleComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: scheduleComponents, repeats: false)
            let request = UNNotificationRequest(identifier: "race-\(days)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    // Reschedule all time-dependent goals and reports
    func rescheduleAllTriggers(settings: UserSettings, context: ModelContext) {
        scheduleWeeklyReport(context: context)
        scheduleGoalReminder(settings: settings, context: context)
        scheduleRaceCountdown(settings: settings)
    }
    
    // MARK: - Helpers
    
    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date, to: .now)
        if let years = components.year, years > 0 {
            let lastDigit = years % 10
            let ending = (lastDigit == 1 && years != 11) ? "год" : ((lastDigit >= 2 && lastDigit <= 4 && (years < 12 || years > 14)) ? "года" : "лет")
            return "\(years) \(ending) назад"
        }
        if let months = components.month, months > 0 {
            let lastDigit = months % 10
            let ending = (lastDigit == 1 && months != 11) ? "месяц" : ((lastDigit >= 2 && lastDigit <= 4 && (months < 12 || months > 14)) ? "месяца" : "месяцев")
            return "\(months) \(ending) назад"
        }
        if let days = components.day, days > 0 {
            let lastDigit = days % 10
            let ending = (lastDigit == 1 && days != 11) ? "день" : ((lastDigit >= 2 && lastDigit <= 4 && (days < 12 || days > 14)) ? "дня" : "дней")
            return "\(days) \(ending) назад"
        }
        return "недавно"
    }
}
