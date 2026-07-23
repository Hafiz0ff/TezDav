// swiftlint:disable cyclomatic_complexity
import Foundation
import SwiftData

enum TrainerStatus: String, Codable, Sendable {
    case overload = "overload"       // Fatigue spike (TSB < -30)
    case recovery = "recovery"       // Overtrained/Missed workouts (compliance < 60%)
    case optimal = "optimal"         // Optimal load zone (-30 <= TSB <= -5)
    case fresh = "fresh"             // Minimal fatigue (-5 < TSB <= 10)
    case underload = "underload"     // Fully recovered / Underloaded (TSB > 10)
}

struct CoachRecommendation: Sendable {
    let ctl: Double
    let atl: Double
    let tsb: Double
    let status: TrainerStatus
    
    let previousWeekStart: Date?
    let targetRunMeters: Double?
    let actualRunMeters: Double?
    let runCompliance: Double?
    
    let targetBikeHours: Double?
    let actualBikeHours: Double?
    let bikeCompliance: Double?
    
    let isAdjustmentRecommended: Bool
    let recommendedRunMeters: Double?
    let recommendedBikeHours: Double?
    
    let insightRU: String
    let insightEN: String
}

enum AICoachEngine {
    
    @MainActor
    static func analyze(
        activities: [Activity],
        plannedWeeks: [TrainingWeek],
        userSettings: UserSettings,
        now: Date = Date()
    ) -> CoachRecommendation {
        let calendar = Calendar.current
        
        // 1. Calculate CTL, ATL, TSB at `now`
        let sortedActivities = activities.sorted { $0.startDate < $1.startDate }
        let loads = sortedActivities.map { ($0.startDate, $0.trainingLoad) }
        let fitnessPoints = TrainingLoadCalculator.performanceManagement(loads: loads)
        
        // Find the last point up to `now`
        let currentPoint = fitnessPoints.filter { $0.date <= now }.last
        let ctl = currentPoint?.ctl ?? 0.0
        let atl = currentPoint?.atl ?? 0.0
        let tsb = currentPoint?.tsb ?? 0.0
        
        // 2. Identify previous week and current week boundaries
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return CoachRecommendation(
                ctl: ctl, atl: atl, tsb: tsb, status: .fresh,
                previousWeekStart: nil, targetRunMeters: nil, actualRunMeters: nil, runCompliance: nil,
                targetBikeHours: nil, actualBikeHours: nil, bikeCompliance: nil,
                isAdjustmentRecommended: false, recommendedRunMeters: nil, recommendedBikeHours: nil,
                insightRU: "Нет данных для планирования.", insightEN: "No planning data available."
            )
        }
        
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) ?? currentWeekStart.addingTimeInterval(-7 * 24 * 3600)
        
        // Find previous week target
        let previousPlannedWeek = plannedWeeks.first { week in
            abs(week.startDate.timeIntervalSince(previousWeekStart)) < 12 * 3600
        }
        
        var actualRunM: Double = 0.0
        var actualBikeH: Double = 0.0
        
        // Filter activities that occurred in the previous week range: [previousWeekStart, currentWeekStart)
        let previousWeekActivities = activities.filter {
            $0.startDate >= previousWeekStart && $0.startDate < currentWeekStart
        }
        
        for activity in previousWeekActivities {
            let sport = activity.sportType.lowercased()
            if sport.contains("run") {
                actualRunM += activity.distanceMeters
            } else if sport.contains("ride") || sport.contains("cycl") {
                actualBikeH += activity.movingTime / 3600.0
            }
        }
        
        var runCompliance: Double? = nil
        var targetRunM: Double? = nil
        if let prevWeek = previousPlannedWeek, prevWeek.targetVolumeMeters > 0 {
            targetRunM = prevWeek.targetVolumeMeters
            runCompliance = actualRunM / prevWeek.targetVolumeMeters
        }
        
        var bikeCompliance: Double? = nil
        var targetBikeH: Double? = nil
        if let prevWeek = previousPlannedWeek, prevWeek.targetCyclingHours > 0 {
            targetBikeH = prevWeek.targetCyclingHours
            bikeCompliance = actualBikeH / prevWeek.targetCyclingHours
        }
        
        // Find next planned week (upcoming week, starts at currentWeekStart)
        let nextPlannedWeek = plannedWeeks.first { week in
            abs(week.startDate.timeIntervalSince(currentWeekStart)) < 12 * 3600
        }
        
        let defaultRunM = nextPlannedWeek?.targetVolumeMeters ?? 0.0
        let defaultBikeH = nextPlannedWeek?.targetCyclingHours ?? 0.0
        
        // 3. Apply Decision Logic
        var status: TrainerStatus = .optimal
        var isAdjustmentRecommended = false
        var recommendedRunM: Double? = nil
        var recommendedBikeH: Double? = nil
        var insightRU = ""
        var insightEN = ""
        
        if tsb < -30.0 {
            // Overtraining (fatigue spike)
            status = .overload
            isAdjustmentRecommended = true
            recommendedRunM = round(defaultRunM * 0.75)
            recommendedBikeH = round(defaultBikeH * 0.75 * 10.0) / 10.0
            insightRU = "Критический уровень утомления (TSB \(Int(round(tsb)))). ИИ-тренер рекомендует снизить объем тренировок на 25% для восстановления организма."
            insightEN = "Critical fatigue level (TSB \(Int(round(tsb)))). AI Coach recommends reducing training targets by 25% for active recovery."
        } else if let rc = runCompliance, rc < 0.60, defaultRunM > 0 {
            // Low running compliance
            status = .recovery
            isAdjustmentRecommended = true
            recommendedRunM = round(defaultRunM * 0.80)
            recommendedBikeH = defaultBikeH > 0 ? round(defaultBikeH * 0.80 * 10.0) / 10.0 : 0.0
            insightRU = "Вы выполнили менее 60% бегового плана на прошлой неделе (\(Int(round(rc * 100)))%). ИИ-тренер скорректировал следующую неделю (-20%) для плавного втягивания."
            insightEN = "You completed less than 60% of running targets last week (\(Int(round(rc * 100)))%). AI Coach lowered next week's goals by 20% to prevent volume spikes."
        } else if let bc = bikeCompliance, bc < 0.60, defaultBikeH > 0 {
            // Low cycling compliance
            status = .recovery
            isAdjustmentRecommended = true
            recommendedRunM = defaultRunM > 0 ? round(defaultRunM * 0.80) : 0.0
            recommendedBikeH = round(defaultBikeH * 0.80 * 10.0) / 10.0
            insightRU = "Вы выполнили менее 60% велосипедного плана на прошлой неделе (\(Int(round(bc * 100)))%). ИИ-тренер снизил цели следующей недели на 20% для адаптации."
            insightEN = "You completed less than 60% of cycling goals last week (\(Int(round(bc * 100)))%). AI Coach reduced next week's volume by 20% for safe progression."
        } else if tsb > 10.0 {
            // Underloaded (high freshness)
            let isTaperOrRecovery = nextPlannedWeek?.typeString.contains("Подвод") == true || nextPlannedWeek?.typeString.contains("Восстанов") == true
            let hadGoodCompliance = (runCompliance ?? 1.0) >= 0.80 && (bikeCompliance ?? 1.0) >= 0.80
            
            if !isTaperOrRecovery && hadGoodCompliance && (defaultRunM > 0 || defaultBikeH > 0) {
                status = .underload
                isAdjustmentRecommended = true
                recommendedRunM = round(defaultRunM * 1.05)
                recommendedBikeH = round(defaultBikeH * 1.05 * 10.0) / 10.0
                insightRU = "Организм полностью отдохнул (TSB \(Int(round(tsb)))). ИИ-тренер рекомендует добавить +5% к тренировочным объемам на следующей неделе."
                insightEN = "Your body is fully recovered (TSB \(Int(round(tsb)))). AI Coach recommends a minor volume increase (+5%) for the upcoming week."
            } else {
                status = .fresh
                insightRU = "Организм свеж и восстановлен (TSB \(Int(round(tsb)))). Продолжайте тренироваться согласно плану."
                insightEN = "Your body is fresh and recovered (TSB \(Int(round(tsb)))). Stick to your current training schedule."
            }
        } else if tsb > -5.0 {
            status = .fresh
            insightRU = "Баланс нагрузки стабильный (TSB \(Int(round(tsb)))). Продолжайте базовую подготовку и соблюдайте график сна."
            insightEN = "Training load is stable (TSB \(Int(round(tsb)))). Keep working on your base volume and stick to recovery."
        } else {
            // Optimal training zone (-30 to -5)
            status = .optimal
            insightRU = "Отличный баланс нагрузки! Вы в оптимальной зоне развития выносливости (TSB \(Int(round(tsb)))). Коррекция плана не требуется."
            insightEN = "Great training balance! You are in the optimal endurance development zone (TSB \(Int(round(tsb)))). No adjustments needed."
        }
        
        return CoachRecommendation(
            ctl: ctl,
            atl: atl,
            tsb: tsb,
            status: status,
            previousWeekStart: previousWeekStart,
            targetRunMeters: targetRunM,
            actualRunMeters: actualRunM,
            runCompliance: runCompliance,
            targetBikeHours: targetBikeH,
            actualBikeHours: actualBikeH,
            bikeCompliance: bikeCompliance,
            isAdjustmentRecommended: isAdjustmentRecommended,
            recommendedRunMeters: recommendedRunM,
            recommendedBikeHours: recommendedBikeH,
            insightRU: insightRU,
            insightEN: insightEN
        )
    }
    
    @MainActor
    static func applyAdaptation(
        recommendation: CoachRecommendation,
        in modelContext: ModelContext,
        plannedWeeks: [TrainingWeek],
        now: Date = Date()
    ) {
        guard recommendation.isAdjustmentRecommended else { return }
        
        let calendar = Calendar.current
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return }
        
        // Find next planned week starting at currentWeekStart
        guard let nextPlannedWeek = plannedWeeks.first(where: {
            abs($0.startDate.timeIntervalSince(currentWeekStart)) < 12 * 3600
        }) else { return }
        
        if let recRun = recommendation.recommendedRunMeters {
            nextPlannedWeek.targetVolumeMeters = round(recRun)
        }
        if let recBike = recommendation.recommendedBikeHours {
            nextPlannedWeek.targetCyclingHours = round(recBike * 10.0) / 10.0
        }
        
        // Tag label
        let tagRU = "(Адапт.)"
        let tagEN = "(Adapted)"
        let tag = AppLanguage.isRussian ? tagRU : tagEN
        
        if !nextPlannedWeek.typeString.contains(tagRU) && !nextPlannedWeek.typeString.contains(tagEN) {
            nextPlannedWeek.typeString += " \(tag)"
        }
        
        try? modelContext.save()
    }
}
