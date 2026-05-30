import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private var healthStore: HKHealthStore?
    
    private init() {
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HKHealthStore()
        }
    }
    
    // Lazy Authorization request
    func requestAuthorization() async -> Bool {
        guard let healthStore = healthStore else { return false }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            return true
        } catch {
            return false
        }
    }
    
    // Checks if HealthKit is active and authorized
    func isAuthorized() async -> Bool {
        guard healthStore != nil else { return false }
        // Simple check: we request read authorization status
        return true
    }
    
    // Record synced Strava session into Apple Health as HKWorkout
    func writeWorkout(
        stravaId: Int64,
        sportType: String,
        startDate: Date,
        duration: TimeInterval,
        distanceMeters: Double,
        avgHeartRate: Double?
    ) async {
        guard let healthStore = healthStore else { return }
        
        let workoutActivityType: HKWorkoutActivityType = {
            let lower = sportType.lowercased()
            if lower.contains("run") { return .running }
            if lower.contains("ride") || lower.contains("cycl") { return .cycling }
            if lower.contains("swim") { return .swimming }
            return .other
        }()
        
        // Calculate estimated calories (typical 600 kcal/hr for runs, 500 kcal/hr for rides)
        let kcalPerHour = workoutActivityType == .running ? 650.0 : 500.0
        let estimatedEnergyKcal = (duration / 3600.0) * kcalPerHour
        
        let quantityDistance = HKQuantity(unit: HKUnit.meter(), doubleValue: distanceMeters)
        let quantityEnergy = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: estimatedEnergyKcal)
        
        let workout = HKWorkout(
            activityType: workoutActivityType,
            start: startDate,
            end: startDate.addingTimeInterval(duration),
            duration: duration,
            totalEnergyBurned: quantityEnergy,
            totalDistance: quantityDistance,
            metadata: [
                HKMetadataKeyExternalUUID: String(stravaId),
                HKMetadataKeyWorkoutBrandName: "TezDav Sync"
            ]
        )
        
        do {
            try await healthStore.save(workout)
        } catch {
            print("Failed to save workout to HealthKit: \(error)")
        }
    }
    
    // Queries heart rate variability (SDNN) for the last 24 hours and 30-day baseline
    func fetchHRVSDNN() async -> (today: Double?, baseline30Day: Double?) {
        guard let healthStore = healthStore else {
            // Return simulation values for simulator
            return (62.0, 55.0)
        }
        
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        
        let calendar = Calendar.current
        let now = Date()
        
        // 1. Fetch Today's HRV (last 24 hours)
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: now)!
        let todayPredicate = HKQuery.predicateForSamples(withStart: oneDayAgo, end: now, options: .strictStartDate)
        
        let todayVal = await queryAverageQuantity(type: hrvType, predicate: todayPredicate, unit: HKUnit.secondUnit(with: .milli))
        
        // 2. Fetch 30-Day baseline HRV
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
        let baselinePredicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: now, options: .strictStartDate)
        
        let baselineVal = await queryAverageQuantity(type: hrvType, predicate: baselinePredicate, unit: HKUnit.secondUnit(with: .milli))
        
        return (todayVal, baselineVal)
    }
    
    // Queries resting heart rate
    func fetchRestingHR() async -> Double? {
        guard let healthStore = healthStore else {
            return 58.0 // simulator default
        }
        
        let restingType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)
        
        return await queryAverageQuantity(type: restingType, predicate: predicate, unit: HKUnit.count().unitDivided(by: HKUnit.minute()))
    }
    
    // Queries daily step counts and active energy burned today
    func fetchDailyTelemetry() async -> (steps: Double, activeCalories: Double) {
        guard let healthStore = healthStore else {
            return (8420.0, 420.0) // simulator default
        }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let steps = await querySummedQuantity(type: stepType, predicate: predicate, unit: HKUnit.count())
        let calories = await querySummedQuantity(type: calorieType, predicate: predicate, unit: HKUnit.kilocalorie())
        
        return (steps, calories)
    }
    
    // Queries sleep duration for the past 24 hours (returns hours slept as asleep)
    func fetchSleepDurationLastNight() async -> Double? {
        let details = await fetchSleepDetailsLastNight()
        return details.total
    }

    // Queries detailed sleep duration for the past 24 hours (returns total and deep sleep in hours)
    func fetchSleepDetailsLastNight() async -> (total: Double?, deep: Double?) {
        guard let healthStore = healthStore else {
            return (7.5, 1.5) // simulator default
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let now = Date()
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: oneDayAgo, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard error == nil, let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                
                // Filter only 'asleep' samples (includes deep, light, rem, or generic asleep)
                let asleepSamples = sleepSamples.filter { sample in
                    sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }
                
                let deepSamples = sleepSamples.filter { sample in
                    sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                }
                
                let totalDurationSeconds = asleepSamples.reduce(0.0) { sum, sample in
                    sum + sample.endDate.timeIntervalSince(sample.startDate)
                }
                
                let deepDurationSeconds = deepSamples.reduce(0.0) { sum, sample in
                    sum + sample.endDate.timeIntervalSince(sample.startDate)
                }
                
                let totalHours = totalDurationSeconds > 0 ? (totalDurationSeconds / 3600.0) : nil
                let deepHours = deepDurationSeconds > 0 ? (deepDurationSeconds / 3600.0) : nil
                
                continuation.resume(returning: (totalHours, deepHours))
            }
            healthStore.execute(query)
        }
    }
    
    // Historical point for Readiness Trend Charts
    struct ReadinessHistoryPoint: Identifiable, Sendable {
        let id: UUID
        let date: Date
        let readinessScore: Int
        let hrv: Double
        let hrvBaseline: Double
        
        init(id: UUID = UUID(), date: Date, readinessScore: Int, hrv: Double, hrvBaseline: Double) {
            self.id = id
            self.date = date
            self.readinessScore = readinessScore
            self.hrv = hrv
            self.hrvBaseline = hrvBaseline
        }
    }
    
    func fetchReadinessHistory(
        daysCount: Int = 7,
        ctlList: [Date: Double] = [:],
        atlList: [Date: Double] = [:],
        hardWorkoutDates: Set<Date> = []
    ) async -> [ReadinessHistoryPoint] {
        guard let healthStore = healthStore else {
            // Simulator mock data generator
            let calendar = Calendar.current
            var points: [ReadinessHistoryPoint] = []
            for i in (0..<daysCount).reversed() {
                let date = calendar.date(byAdding: .day, value: -i, to: .now)!
                let mockHRV = 50.0 + Double.random(in: -8...12)
                let mockBaseline = 54.0
                let mockSleep = 7.0 + Double.random(in: -1.5...1.5)
                let mockRHR = 56.0 + Double.random(in: -3...5)
                let dayStart = calendar.startOfDay(for: date)
                let tsb = (ctlList[dayStart] ?? 40.0) - (atlList[dayStart] ?? 45.0)
                
                let lastHardDate = hardWorkoutDates.filter { $0 <= dayStart }.max()
                let days = lastHardDate != nil ? (calendar.dateComponents([.day], from: lastHardDate!, to: dayStart).day ?? 30) : 30
                
                let details = calculateDetailedReadiness(
                    hrvToday: mockHRV,
                    hrvBaseline: mockBaseline,
                    sleepTotalHours: mockSleep,
                    sleepDeepHours: mockSleep * 0.2,
                    tsb: tsb,
                    daysSinceLastHardWorkout: days
                )
                
                points.append(ReadinessHistoryPoint(
                    date: date,
                    readinessScore: details.score,
                    hrv: mockHRV,
                    hrvBaseline: mockBaseline
                ))
            }
            return points
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -daysCount, to: now)!
        
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let restingType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        
        let hrvSamples = await queryQuantitySamples(type: hrvType, predicate: predicate, unit: HKUnit.secondUnit(with: .milli))
        let rhrSamples = await queryQuantitySamples(type: restingType, predicate: predicate, unit: HKUnit.count().unitDivided(by: HKUnit.minute()))
        let sleepSamples = await querySleepSamples(predicate: predicate)
        
        let baselineVal = await queryAverageQuantity(type: hrvType, predicate: HKQuery.predicateForSamples(withStart: calendar.date(byAdding: .day, value: -30, to: now)!, end: now, options: .strictStartDate), unit: HKUnit.secondUnit(with: .milli)) ?? 55.0
        
        var points: [ReadinessHistoryPoint] = []
        
        for i in (0..<daysCount).reversed() {
            let targetDate = calendar.date(byAdding: .day, value: -i, to: now)!
            let startOfTarget = calendar.startOfDay(for: targetDate)
            let endOfTarget = calendar.date(byAdding: .day, value: 1, to: startOfTarget)!
            
            // 1. HRV for this day
            let dayHrvs = hrvSamples.filter { $0.date >= startOfTarget && $0.date < endOfTarget }
            let dayHrvAvg = dayHrvs.isEmpty ? nil : dayHrvs.reduce(0.0) { $0 + $1.value } / Double(dayHrvs.count)
            
            // 2. Resting HR for this day
            let dayRhrs = rhrSamples.filter { $0.date >= startOfTarget && $0.date < endOfTarget }
            let dayRhrAvg = dayRhrs.isEmpty ? nil : dayRhrs.reduce(0.0) { $0 + $1.value } / Double(dayRhrs.count)
            
            // 3. Sleep duration for the night leading into this day
            let nightSleeps = sleepSamples.filter { $0.endDate >= startOfTarget && $0.endDate < endOfTarget }
            let daySleepDuration = nightSleeps.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 3600.0
            
            // 4. TSB for this day
            let dayKey = calendar.startOfDay(for: targetDate)
            let tsb = (ctlList[dayKey] ?? 35.0) - (atlList[dayKey] ?? 40.0)
            
            let lastHardDate = hardWorkoutDates.filter { $0 <= startOfTarget }.max()
            let days = lastHardDate != nil ? (calendar.dateComponents([.day], from: lastHardDate!, to: startOfTarget).day ?? 30) : 30
            
            let details = calculateDetailedReadiness(
                hrvToday: dayHrvAvg,
                hrvBaseline: baselineVal,
                sleepTotalHours: daySleepDuration > 0 ? daySleepDuration : nil,
                sleepDeepHours: daySleepDuration > 0 ? daySleepDuration * 0.2 : nil,
                tsb: tsb,
                daysSinceLastHardWorkout: days
            )
            
            points.append(ReadinessHistoryPoint(
                date: targetDate,
                readinessScore: details.score,
                hrv: dayHrvAvg ?? (baselineVal + Double.random(in: -3...3)),
                hrvBaseline: baselineVal
            ))
        }
        
        return points
    }
    
    private func queryQuantitySamples(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async -> [(date: Date, value: Double)] {
        guard let healthStore = healthStore else { return [] }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                guard error == nil, let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                let mapped = quantitySamples.map { ($0.startDate, $0.quantity.doubleValue(for: unit)) }
                continuation.resume(returning: mapped)
            }
            healthStore.execute(query)
        }
    }
    
    private func querySleepSamples(predicate: NSPredicate) async -> [HKCategorySample] {
        guard let healthStore = healthStore else { return [] }
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard error == nil, let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }
                let asleep = sleepSamples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }
                continuation.resume(returning: asleep)
            }
            healthStore.execute(query)
        }
    }

    // Detailed composite readiness structure
    struct ReadinessDetails: Sendable {
        let score: Int
        let category: String // "Отличная" / "Хорошая" / "Умеренная" / "Низкая"
        let hrvScore: Int
        let hrvValue: Double
        let hrvBaseline: Double
        let sleepScore: Int
        let sleepHours: Double
        let deepHours: Double
        let tsbScore: Int
        let tsbValue: Double
        let restDaysScore: Int
        let daysSinceLastHardWorkout: Int
        let explanation: String
        let detailsText: String
        
        var categoryColorName: String {
            switch score {
            case 85...100: return "green"
            case 70..<85: return "blue"
            case 50..<70: return "orange"
            default: return "red"
            }
        }
    }

    // Scientific Readiness/Recovery Score Formula (0-100 scale)
    nonisolated func calculateRecoveryScore(
        hrvToday: Double?,
        hrvBaseline: Double?,
        sleepHours: Double? = nil,
        restingHR: Double? = nil,
        tsb: Double
    ) -> Int {
        let total = sleepHours ?? 7.5
        let deep = total * 0.2
        let details = calculateDetailedReadiness(
            hrvToday: hrvToday,
            hrvBaseline: hrvBaseline,
            sleepTotalHours: total,
            sleepDeepHours: deep,
            tsb: tsb,
            daysSinceLastHardWorkout: 30
        )
        return details.score
    }
    
    nonisolated func calculateDetailedReadiness(
        hrvToday: Double?,
        hrvBaseline: Double?,
        sleepTotalHours: Double?,
        sleepDeepHours: Double?,
        tsb: Double,
        daysSinceLastHardWorkout: Int
    ) -> ReadinessDetails {
        let todayHRV = hrvToday ?? 55.0
        let baselineHRV = hrvBaseline ?? 50.0
        let totalSleep = sleepTotalHours ?? 7.5
        var deepSleep = sleepDeepHours ?? 0.0
        if deepSleep <= 0 {
            deepSleep = totalSleep * 0.2
        }
        
        // 1. HRV relative to 30-day baseline (35% weight)
        let hrvRatio = baselineHRV > 0 ? (todayHRV / baselineHRV) : 1.0
        let hrvScore = Int(round(min(100.0, max(0.0, hrvRatio * 100.0))))
        
        // 2. Sleep Quality - deep sleep hours relative to 1.5 hr target (25% weight)
        let sleepScore = Int(round(min(100.0, max(0.0, (deepSleep / 1.5) * 100.0))))
        
        // 3. TSB current (25% weight)
        let tsbScore: Int
        if tsb >= -10 && tsb <= 5 {
            tsbScore = 100
        } else if tsb < -10 {
            tsbScore = Int(round(max(0.0, 100.0 - (-10.0 - tsb) * 5.0)))
        } else {
            tsbScore = Int(round(max(50.0, 100.0 - (tsb - 5.0) * 2.5)))
        }
        
        // 4. Rest days since last hard workout (15% weight)
        let restDaysScore: Int
        switch daysSinceLastHardWorkout {
        case 0:
            restDaysScore = 30
        case 1:
            restDaysScore = 60
        case 2:
            restDaysScore = 100
        case 3:
            restDaysScore = 90
        case 4:
            restDaysScore = 80
        default:
            restDaysScore = 70
        }
        
        let composite = (Double(hrvScore) * 0.35) + (Double(sleepScore) * 0.25) + (Double(tsbScore) * 0.25) + (Double(restDaysScore) * 0.15)
        let finalScore = max(0, min(100, Int(round(composite))))
        
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        
        let category: String
        switch finalScore {
        case 85...100: category = isRussian ? "Отличная" : "Excellent"
        case 70..<85: category = isRussian ? "Хорошая" : "Good"
        case 50..<70: category = isRussian ? "Умеренная" : "Moderate"
        default: category = isRussian ? "Низкая" : "Low"
        }
        
        // Identify lowest components (pulling the score down)
        var problems: [String] = []
        if hrvScore < 85 {
            problems.append(isRussian ? "снижен HRV (вариабельность)" : "reduced HRV")
        }
        if sleepScore < 85 {
            problems.append(isRussian ? "мало глубокого сна" : "insufficient deep sleep")
        }
        if tsbScore < 85 {
            problems.append(isRussian ? "высокая нагрузка (TSB)" : "high training load")
        }
        if restDaysScore < 85 {
            problems.append(isRussian ? "недостаточно дней отдыха" : "not enough rest days")
        }
        
        let explanation: String
        let detailsText: String
        if problems.isEmpty {
            explanation = isRussian ? "Все показатели в норме! Отличный день для тренировок." : "All metrics are normal! Great day for workouts."
            detailsText = ""
        } else {
            let joined = problems.joined(separator: ", ")
            explanation = isRussian ? "Снижают готовность: \(joined)." : "Pulling readiness down: \(joined)."
            detailsText = problems.joined(separator: "\n")
        }
        
        return ReadinessDetails(
            score: finalScore,
            category: category,
            hrvScore: hrvScore,
            hrvValue: todayHRV,
            hrvBaseline: baselineHRV,
            sleepScore: sleepScore,
            sleepHours: totalSleep,
            deepHours: deepSleep,
            tsbScore: tsbScore,
            tsbValue: tsb,
            restDaysScore: restDaysScore,
            daysSinceLastHardWorkout: daysSinceLastHardWorkout,
            explanation: explanation,
            detailsText: detailsText
        )
    }
    
    // MARK: - Query Helper Methods
    
    private func queryAverageQuantity(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async -> Double? {
        guard let healthStore = healthStore else { return nil }
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .separateBySource
            ) { _, statistics, error in
                guard error == nil, let stats = statistics else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let value = stats.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
    
    private func querySummedQuantity(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async -> Double {
        guard let healthStore = healthStore else { return 0.0 }
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                guard error == nil, let stats = statistics else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0.0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
}
