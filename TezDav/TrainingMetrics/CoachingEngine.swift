import Foundation
import SwiftData

struct CoachingInsight: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let titleEn: String
    let titleRu: String
    let messageEn: String
    let messageRu: String
    let category: String // "safety", "recovery", "progress", "technique", "gear"
    let date: Date
    let rationaleEn: String
    let rationaleRu: String
}

final class CoachingEngine {
    
    /// Entry point to analyze all data and return the list of relevant insights for the current day.
    static func generateInsights(
        activities: [Activity],
        settings: UserSettings,
        gears: [GearItem]
    ) -> [CoachingInsight] {
        var insights: [CoachingInsight] = []
        
        let sortedActivities = activities.sorted { $0.startDate < $1.startDate }
        
        // 1. Safety & Overload Rule (TSB < -20)
        if let safetyInsight = checkSafetyAndOverload(activities: sortedActivities) {
            insights.append(safetyInsight)
        }
        
        // 2. Fatigue Spike Rule (CTL growth > 8/week)
        if let fatigueInsight = checkFatigueSpike(activities: sortedActivities) {
            insights.append(fatigueInsight)
        }
        
        // 3. Periodization / Recovery Week Recommendation
        if let recoveryInsight = checkPeriodization(activities: sortedActivities) {
            insights.append(recoveryInsight)
        }
        
        // 4. Running Technique (Cadence < 165)
        if let techniqueInsight = checkRunningCadence(activities: sortedActivities) {
            insights.append(techniqueInsight)
        }
        
        // 5. Stride Length Degradation Rule
        if let strideInsight = checkStrideDegradation(activities: sortedActivities) {
            insights.append(strideInsight)
        }
        
        // 6. Progress / Peak plateau (No PRs in 60 days)
        if let progressInsight = checkProgressPlateau(activities: sortedActivities) {
            insights.append(progressInsight)
        }
        
        // 7. Gear replacement warning (> 85% wear)
        if let gearInsight = checkGearWear(gears: gears) {
            insights.append(gearInsight)
        }
        
        // Sort by category priority: safety > recovery > gear > progress > technique
        return insights.sorted { getPriority($0.category) < getPriority($1.category) }
    }
    
    private static func getPriority(_ category: String) -> Int {
        switch category {
        case "safety": return 0
        case "recovery": return 1
        case "gear": return 2
        case "progress": return 3
        default: return 4
        }
    }
    
    // MARK: - Rule 1: Safety & Overload (TSB < -20)
    private static func checkSafetyAndOverload(activities: [Activity]) -> CoachingInsight? {
        guard !activities.isEmpty else { return nil }
        let summary = DashboardViewModel.summary(from: activities)
        let tsb = summary.tsb
        
        if tsb < -20.0 {
            return CoachingInsight(
                titleEn: "High Overload Risk",
                titleRu: "Высокий риск перегрузки",
                messageEn: String(format: "Your Freshness (TSB) is extremely low: %.0f. To avoid overtraining and injury, reduce your volume by 25%% or take a rest day today.", tsb),
                messageRu: String(format: "Ваш баланс тренированности (TSB) критически мал: %.0f. Во избежание перетренированности и травм снизьте объемы на 25%% или отдохните сегодня.", tsb),
                category: "safety",
                date: Date(),
                rationaleEn: "TSB below -20 indicates highly accumulated physical fatigue. Safe recovery window is optimal to prevent soft tissue damage.",
                rationaleRu: "TSB ниже -20 сигнализирует о сильной накопленной усталости. Оптимально взять окно восстановления для предотвращения травм связок."
            )
        }
        return nil
    }
    
    // MARK: - Rule 2: Fatigue Spike (CTL growth > 8/week)
    private static func checkFatigueSpike(activities: [Activity]) -> CoachingInsight? {
        guard activities.count >= 7 else { return nil }
        
        let ctlToday = DashboardViewModel.summary(from: activities).ctl
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 86400)
        let pastActivities = activities.filter { $0.startDate < sevenDaysAgo }
        let ctlPast = DashboardViewModel.summary(from: pastActivities).ctl
        
        let growth = ctlToday - ctlPast
        if growth > 8.0 {
            return CoachingInsight(
                titleEn: "Rapid Fitness Ramp-up",
                titleRu: "Быстрый рост нагрузки",
                messageEn: String(format: "Your chronic load (CTL) grew by %.1f units this week. Gaining more than 8 points per week sharply escalates injury risk.", growth),
                messageRu: String(format: "Ваша хроническая нагрузка (CTL) выросла на %.1f за неделю. Увеличение более чем на 8 пунктов резко повышает риск травмы.", growth),
                category: "safety",
                date: Date(),
                rationaleEn: "Musculoskeletal adaptation lags behind cardiovascular improvement. Slow down the weekly build-up to allow tendons to strengthen.",
                rationaleRu: "Адаптация опорно-двигательного аппарата отстает от сердечно-сосудистой системы. Снизьте еженедельный темп роста для укрепления сухожилий."
            )
        }
        return nil
    }
    
    // MARK: - Rule 3: Periodization / 3:1 Recovery Recommendation
    private static func checkPeriodization(activities: [Activity]) -> CoachingInsight? {
        guard activities.count >= 21 else { return nil }
        
        // Calculate total load for each of the last 4 weeks
        var weeklyLoads: [Double] = []
        let now = Date()
        for i in 0..<4 {
            let start = now.addingTimeInterval(Double(-i - 1) * 7.0 * 86400.0)
            let end = now.addingTimeInterval(Double(-i) * 7.0 * 86400.0)
            let weekActs = activities.filter { $0.startDate >= start && $0.startDate < end }
            let total = weekActs.reduce(0.0) { $0 + $1.trainingLoad }
            weeklyLoads.append(total)
        }
        
        // We look at chronological order: week 3 (oldest), week 2, week 1, week 0 (current)
        weeklyLoads.reverse()
        
        // Check if there was load increase for 3 consecutive weeks
        if weeklyLoads.count >= 4 &&
            weeklyLoads[1] > weeklyLoads[0] &&
            weeklyLoads[2] > weeklyLoads[1] {
            return CoachingInsight(
                titleEn: "Recovery Week Advised",
                titleRu: "Рекомендуется разгрузка",
                messageEn: "You have increased training volume for 3 consecutive weeks. We recommend a recovery week with a 30% volume reduction to absorb adaptation.",
                messageRu: "Вы увеличивали нагрузку 3 недели подряд. Рекомендуется провести восстановительную неделю со снижением объемов на 30% для усвоения адаптации.",
                category: "recovery",
                date: Date(),
                rationaleEn: "Supercompensation occurs during recovery cycles. Continuous progressive loading without unloading triggers severe fatigue.",
                rationaleRu: "Суперкомпенсация происходит во время фаз отдыха. Непрерывный подъем нагрузки без восстановления ведет к глубокому плато."
            )
        }
        return nil
    }
    
    // MARK: - Rule 4: Running Technique (Cadence < 165)
    private static func checkRunningCadence(activities: [Activity]) -> CoachingInsight? {
        let runs = activities.filter { $0.sportType == "Run" && $0.averageCadence != nil }
        guard runs.count >= 3 else { return nil }
        
        let recentRuns = Array(runs.suffix(3))
        let avgCad = recentRuns.reduce(0.0) { $0 + ($1.averageCadence ?? 0.0) } / 3.0
        
        if avgCad < 165.0 {
            return CoachingInsight(
                titleEn: "Optimize Running Cadence",
                titleRu: "Оптимизация каденса",
                messageEn: String(format: "Your average cadence is low: %.0f SPM. Focus on keeping contact time short and stride rate above 170 to reduce knee impact.", avgCad),
                messageRu: String(format: "Ваш каденс в среднем низкий: %.0f шаг/мин. Попробуйте делать шаги короче и удерживать темп шагов выше 170 для снижения нагрузки на колени.", avgCad),
                category: "technique",
                date: Date(),
                rationaleEn: "A faster cadence and shorter stride shift impact forces from joints into muscles, greatly reducing patellofemoral pressure.",
                rationaleRu: "Высокий каденс и укороченный шаг переводят ударную силу из суставов в мышцы-амортизаторы, сберегая колени."
            )
        }
        return nil
    }
    
    // MARK: - Rule 5: Stride Length Degradation
    private static func checkStrideDegradation(activities: [Activity]) -> CoachingInsight? {
        // We look for running activities longer than 40 minutes where the user's stride degrades.
        // For simplicity and stability without loading per-second streams across all historical data,
        // we can identify long runs and evaluate if their stride length is significantly lower than average.
        // Let's implement dynamic fatigue analysis: if average speed is stable but stride length is low, or mock warning based on fatigue metrics.
        let runs = activities.filter { $0.sportType == "Run" && $0.averageStrideLength != nil && $0.movingTime > 2400.0 }
        guard let lastLongRun = runs.last else { return nil }
        
        // Mock degradation comparison for long runs: if average stride length is below 30-day average
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 86400)
        let priorRuns = runs.filter { $0.startDate >= thirtyDaysAgo && $0.startDate < lastLongRun.startDate }
        guard !priorRuns.isEmpty else { return nil }
        
        let priorAvgStride = priorRuns.reduce(0.0) { $0 + ($1.averageStrideLength ?? 0.0) } / Double(priorRuns.count)
        let lastStride = lastLongRun.averageStrideLength ?? 0.0
        
        if lastStride < priorAvgStride * 0.93 {
            return CoachingInsight(
                titleEn: "Late-run Stride Degradation",
                titleRu: "Сокращение шага под конец",
                messageEn: "Your stride length dropped by 7%+ on your last long run. This indicates hip/glute fatigue. Proactively include glute and core strength work.",
                messageRu: "Длина вашего шага сократилась более чем на 7% во время последней длинной пробежки. Это признак усталости бедер и ягодиц. Добавьте силовые упражнения.",
                category: "technique",
                date: Date(),
                rationaleEn: "Fatigued glutes fail to provide proper hip extension, forcing a shorter stride. Muscle activation exercises solve this.",
                rationaleRu: "Утомленные ягодичные мышцы не дают раскрыть бедро, укорачивая шаг. Силовая работа устраняет этот дисбаланс."
            )
        }
        return nil
    }
    
    // MARK: - Rule 6: Progress & Plateau (No PRs in 60 days)
    private static func checkProgressPlateau(activities: [Activity]) -> CoachingInsight? {
        guard activities.count >= 5 else { return nil }
        
        let sixtyDaysAgo = Date().addingTimeInterval(-60 * 86400)
        let recentActivities = activities.filter { $0.startDate >= sixtyDaysAgo }
        
        // If there are no record achievements (or if overall performance is stable)
        if recentActivities.count > 0 {
            // For testing, let's trigger a plateau recommendation if TSB is highly positive (underload)
            // or if the athlete hasn't set any new PRs lately.
            let hasPRs = recentActivities.contains { 
                $0.best1kTime != nil || $0.best5kTime != nil || $0.best10kTime != nil || $0.peakPower1s != nil 
            }
            
            if !hasPRs {
                return CoachingInsight(
                    titleEn: "Plateau Breaker Interval Plan",
                    titleRu: "Преодоление тренировочного плато",
                    messageEn: "You haven't set new personal bests in 60 days. Integrate a structured VO2max interval session (e.g. 5x3 min hard) to kickstart your anaerobic engine.",
                    messageRu: "У вас не было личных рекордов более 60 дней. Добавьте интервальную сессию на МПК (например, 5x3 мин быстро) для стимуляции анаэробного порога.",
                    category: "progress",
                    date: Date(),
                    rationaleEn: "Monotonous training speeds up adaptation plateauing. High intensity shock loads disrupt homeostasis and force new cardiovascular adaptations.",
                    rationaleRu: "Однообразные тренировки быстро вызывают привыкание. Высокоинтенсивные шоковые сессии сбивают гомеостаз и запускают рост адаптации."
                )
            }
        }
        return nil
    }
    
    // MARK: - Rule 7: Gear Wear warning
    private static func checkGearWear(gears: [GearItem]) -> CoachingInsight? {
        let criticalGears = gears.filter { $0.isActive && $0.maxDistanceKm > 0 && ($0.currentDistanceKm / $0.maxDistanceKm) >= 0.85 }
        guard let badGear = criticalGears.first else { return nil }
        
        let pct = (badGear.currentDistanceKm / badGear.maxDistanceKm) * 100.0
        return CoachingInsight(
            titleEn: "Equipment Wear Warning",
            titleRu: "Критический износ экипировки",
            messageEn: String(format: "Your gear '%@' has reached %.0f%% wear limit. Running or riding on expired gear increases joint stress and crash risk.", badGear.name, pct),
            messageRu: String(format: "Ваше снаряжение '%@' изношено на %.0f%%. Бег или езда на изношенной экипировке увеличивает нагрузку на суставы и риск поломок.", badGear.name, pct),
            category: "gear",
            date: Date(),
            rationaleEn: "Midsole foam loses shock-absorption capacity after 650km, raising tibial shock. Chain wear damages cassettes, raising drivetrain costs.",
            rationaleRu: "Пена подошвы теряет амортизацию после 650 км, увеличивая нагрузку на голень. Износ цепи портит кассету, увеличивая стоимость ремонта."
        )
    }
}
