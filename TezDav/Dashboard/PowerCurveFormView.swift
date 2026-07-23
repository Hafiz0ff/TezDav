// swiftlint:disable cyclomatic_complexity
import SwiftUI
import SwiftData

struct PowerCurveFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Query private var settingsList: [UserSettings]
    
    @State private var selectedPeriod: CurvePeriod = .ninetyDays
    @State private var metricType: MetricType = .absolute
    @State private var selectedPoint: PowerPoint? = nil
    
    enum CurvePeriod: String, CaseIterable, Identifiable {
        case twentyEightDays = "28 дней"
        case ninetyDays = "90 дней"
        case oneYear = "365 дней"
        case allTime = "Всё время"
        
        var id: String { self.rawValue }
        
        var daysLimit: Int? {
            switch self {
            case .twentyEightDays: return 28
            case .ninetyDays: return 90
            case .oneYear: return 365
            case .allTime: return nil
            }
        }
    }
    
    enum MetricType: String, CaseIterable, Identifiable {
        case absolute = "Абсолютная (Вт)"
        case relative = "Относительная (Вт/кг)"
        
        var id: String { self.rawValue }
    }
    
    private var settings: UserSettings {
        settingsList.first ?? UserSettings()
    }
    
    private var athleteWeight: Double {
        settings.weightKg
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Period and Metric Selectors
            VStack(spacing: 12) {
                Picker("Период", selection: $selectedPeriod) {
                    ForEach(CurvePeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Метрика", selection: $metricType) {
                    Text("Абсолютная (Вт)").tag(MetricType.absolute)
                    Text(settings.isMetric ? "Относительная (Вт/кг)" : "Относительная (Вт/фунт)").tag(MetricType.relative)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            
            let curveData = calculateCurveData()
            
            if curveData.isEmpty {
                ContentUnavailableView(
                    "Нет данных мощности",
                    systemImage: "bolt.heart.fill",
                    description: Text("Импортируйте FIT-файлы с тренировок с датчиком мощности для построения кривой.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Chart Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Индивидуальный профиль мощности")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            PowerCurveChartView(
                                points: curveData,
                                useRelative: metricType == .relative,
                                selectedPoint: $selectedPoint
                            )
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        
                        // Selected Effort Detail Card
                        if let selected = selectedPoint {
                            selectedEffortCard(selected)
                        } else {
                            // Default hint
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                                Text("Нажмите на точку на графике, чтобы посмотреть детали рекорда.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Critical Power & W' solver results
                        let cpResult = calculateCriticalPower(from: curveData)
                        criticalPowerCard(result: cpResult)
                        
                        // Training Zones based on CP
                        powerZonesSection(criticalPower: cpResult.criticalPower)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
    }
    
    // MARK: - Helper calculations
    
    private func calculateCurveData() -> [PowerPoint] {
        let calendar = Calendar.current
        let cutoffDate = selectedPeriod.daysLimit.flatMap { calendar.date(byAdding: .day, value: -$0, to: .now) }
        
        let filteredActivities = activities.filter { act in
            guard act.sportType == "Ride" || act.averagePower != nil else { return false }
            if let cutoff = cutoffDate {
                return act.startDate >= cutoff
            }
            return true
        }
        
        let durations = [1, 5, 15, 30, 60, 120, 300, 600, 1200, 3600]
        var maxWatts: [Int: (watts: Double, date: Date, name: String)] = [:]
        
        for duration in durations {
            for act in filteredActivities {
                let val: Double? = {
                    switch duration {
                    case 1: return act.peakPower1s
                    case 5: return act.peakPower5s
                    case 15: return act.peakPower15s
                    case 30: return act.peakPower30s
                    case 60: return act.peakPower1m
                    case 120: return act.peakPower2m
                    case 300: return act.peakPower5m
                    case 600: return act.peakPower10m
                    case 1200: return act.peakPower20m
                    case 3600: return act.peakPower60m
                    default: return nil
                    }
                }()
                
                if let watts = val, watts > 0 {
                    let currentMax = maxWatts[duration]?.watts ?? 0.0
                    if watts > currentMax {
                        maxWatts[duration] = (watts: watts, date: act.startDate, name: act.name)
                    }
                }
            }
        }
        
        guard !maxWatts.isEmpty else { return [] }
        
        let isMetric = settings.isMetric
        let baseWeight = athleteWeight > 0 ? athleteWeight : 70.0
        let weight = isMetric ? baseWeight : (baseWeight * 2.20462)
        
        return durations.compactMap { duration -> PowerPoint? in
            guard let record = maxWatts[duration] else { return nil }
            return PowerPoint(
                duration: duration,
                durationLabel: labelForDuration(duration),
                watts: record.watts,
                relativeWatts: record.watts / weight,
                type: "Рекорд",
                date: record.date
            )
        }
    }
    
    private func labelForDuration(_ d: Int) -> String {
        switch d {
        case 1: return "1с"
        case 5: return "5с"
        case 15: return "15с"
        case 30: return "30с"
        case 60: return "1м"
        case 120: return "2м"
        case 300: return "5м"
        case 600: return "10m"
        case 1200: return "20m"
        case 3600: return "1ч"
        default: return "\(d)s"
        }
    }
    
    private func calculateCriticalPower(from data: [PowerPoint]) -> CriticalPowerSolver.CPResult {
        var mmp: [Int: Double] = [:]
        for pt in data {
            mmp[pt.duration] = pt.watts
        }
        return CriticalPowerSolver.solve(mmp: mmp, defaultFTP: settings.cyclingFTP)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func selectedEffortCard(_ pt: PowerPoint) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Детали рекорда (\(pt.durationLabel))")
                    .font(.headline)
                Spacer()
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Мощность")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(pt.watts)) Вт")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.blue)
                }
                
                VStack(alignment: .leading) {
                    Text("Удельная")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: settings.isMetric ? "%.2f Вт/кг" : "%.2f Вт/фунт", pt.relativeWatts))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.blue)
                }
                
                Spacer()
            }
            
            if let date = pt.date {
                Divider()
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func criticalPowerCard(result: CriticalPowerSolver.CPResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Физиологический профиль")
                    .font(.headline)
                Spacer()
                if result.isEstimated {
                    Text("Оценка по умолчанию")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2), in: Capsule())
                        .foregroundStyle(.orange)
                } else {
                    Text("Рассчитано")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2), in: Capsule())
                        .foregroundStyle(.green)
                }
            }
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Критическая мощность (CP)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(result.criticalPower)) Вт")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.blue)
                    let baseWeight = athleteWeight > 0 ? athleteWeight : 70.0
                    let displayWeight = settings.isMetric ? baseWeight : (baseWeight * 2.20462)
                    let unitLabel = settings.isMetric ? "Вт/кг" : "Вт/фунт"
                    Text(String(format: "%.1f %@", result.criticalPower / displayWeight, unitLabel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider().frame(height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Анаэробная емкость (W')")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f кДж", result.wPrime / 1000.0))
                        .font(.title.weight(.bold))
                        .foregroundStyle(.purple)
                    Text("Запас надпороговой энергии")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Text("Критическая мощность (CP) — это максимальная интенсивность, которую вы можете поддерживать длительное время без прогрессирующего утомления. W' — количество энергии, доступное при работе выше уровня CP.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func powerZonesSection(criticalPower: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Тренировочные зоны мощности")
                .font(.headline)
                .padding(.horizontal, 4)
            
            let zones = [
                ("Зона 1: Активное восстановление", 0.0, 0.55, Color.gray),
                ("Зона 2: Выносливость (Аэробная)", 0.55, 0.75, Color.green),
                ("Зона 3: Темп", 0.75, 0.90, Color.blue),
                ("Зона 4: Лактатный порог (FTP)", 0.90, 1.05, Color.yellow),
                ("Зона 5: VO2 Max (МПК)", 1.05, 1.20, Color.orange),
                ("Зона 6: Анаэробная емкость", 1.20, 2.0, Color.red)
            ]
            
            VStack(spacing: 8) {
                ForEach(zones, id: \.0) { zone in
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(zone.3)
                            .frame(width: 8, height: 24)
                        
                        Text(zone.0)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        let minW = Int(criticalPower * zone.1)
                        let maxW = zone.2 > 1.9 ? "" : " - \(Int(criticalPower * zone.2)) Вт"
                        let label = zone.2 > 1.9 ? "> \(minW) Вт" : "\(minW)\(maxW)"
                        
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(.thinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
