import Charts
import SwiftData
import SwiftUI

struct DailyMetrics: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let ctl: Double
    let atl: Double
    let tsb: Double
    let load: Double
    var isPrediction: Bool = false
}

struct WeeklyMetric: Identifiable, Equatable {
    let id = UUID()
    let weekStart: Date
    let totalLoad: Double
}

struct FormView: View {
    @Query(sort: \Activity.startDate, order: .forward) private var activities: [Activity]
    @Query(sort: \TrainingWeek.startDate, order: .forward) private var plannedWeeks: [TrainingWeek]
    @Query(sort: \PlannedWorkout.date, order: .forward) private var plannedWorkouts: [PlannedWorkout]
    @Query private var userSettings: [UserSettings]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingAddPlannedWorkout = false
    
    private var activeUserSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }
    
    enum FormTab: String, CaseIterable, Identifiable {
        case pmc = "PMC"
        case hrv = "Готовность (ВСР)"
        case powerCurve = "Кривая мощности"
        case dynamics = "Динамика бега"
        case weather = "Погода"
        var id: String { self.rawValue }
        
        var displayName: String {
            let isRussian = AppLanguage.isRussian
            switch self {
            case .pmc: return isRussian ? "Форма" : "PMC"
            case .hrv: return isRussian ? "Готовность" : "Readiness"
            case .powerCurve: return isRussian ? "Мощность" : "Power Curve"
            case .dynamics: return isRussian ? "Динамика" : "Dynamics"
            case .weather: return isRussian ? "Погода" : "Weather"
            }
        }
    }
    
    @State private var selectedTab: FormTab = .pmc
    @State private var selectedPeriod: Period = .threeMonths
    @State private var selectedDate: Date? = nil
    @State private var isShowingPlanner = false
    @State private var drawTracker = 0.0
    
    @State private var readinessHistory: [HealthKitManager.ReadinessHistoryPoint] = []
    @State private var sleepHoursToday: Double? = nil
    @State private var sleepDeepHoursToday: Double? = nil
    @State private var restingHRToday: Double? = nil
    @State private var hrvToday: Double? = nil
    @State private var hrvBaseline: Double? = nil
    @State private var isLoadingReadiness = false
    @State private var readinessPeriodDays: Int = 7
    
    enum Period: String, CaseIterable, Identifiable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case all = "All"
        
        var id: String { self.rawValue }

        var displayName: String {
            switch self {
            case .oneMonth: return "1 мес"
            case .threeMonths: return "3 мес"
            case .sixMonths: return "6 мес"
            case .oneYear: return "1 год"
            case .all: return "Всё"
            }
        }
        
        var daysCount: Int? {
            switch self {
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .oneYear: return 365
            case .all: return nil
            }
        }
    }

    private var daysSpan: Int {
        guard let first = activities.first?.startDate, let last = activities.last?.startDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: first), to: Calendar.current.startOfDay(for: last)).day ?? 0
    }

    @ViewBuilder
    private var tabSelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassSegmentedControl(
                options: FormTab.allCases,
                selection: $selectedTab,
                title: { $0.displayName }
            )
            .frame(minWidth: 500)
            .padding(.horizontal, DesignTokens.Spacing.screen)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var periodSelectorView: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            GlassSegmentedControl(
                options: Period.allCases,
                selection: $selectedPeriod,
                title: { $0.displayName }
            )
            
            Button {
                HapticManager.trigger(.light)
                isShowingPlanner = true
            } label: {
                Image(systemName: "calendar")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 42, height: 42)
                    .liquidGlassControl(shape: .circle)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func pmcTabViewContent(allDaily: [DailyMetrics], filteredDaily: [DailyMetrics], weeklyLoad: [WeeklyMetric], currentStatus: DailyMetrics?) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Period Selector
                periodSelectorView
                
                // 1. TSB Interpretation Card
                if let currentStatus {
                    tsbInterpretationSection(currentStatus)
                }
                
                // 2. Main PMC Line Chart
                pmcChartSection(filteredDaily)
                
                // 3. Metrics Columns Row
                if let currentStatus {
                    metricsRowSection(currentStatus)
                }
                
                // 4. Weekly Load Bar Chart
                weeklyLoadSection(filterWeekly(weeklyLoad))
                
                // 5. Daily Volume bar chart
                CustomWeeklyVolumeChart(activities: activities, settings: activeUserSettings)
                
                // 6. Forecast & Planner Section
                forecastPlannerSection()
                
                Spacer()
                    .frame(height: 120)
            }
            .padding(.horizontal, DesignTokens.Spacing.screen)
            .padding(.top, 4)
        }
    }

    var body: some View {
        Group {
            if activities.isEmpty {
                TezDavEmptyState(
                    symbol: "waveform.path.ecg.rectangle",
                    title: "Нет данных о форме",
                    message: "Импортируйте тренировки, чтобы рассчитать CTL, ATL и TSB."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                        tabSelectorView
                        
                        if selectedTab == .pmc {
                            if daysSpan < 14 {
                                ContentUnavailableView(
                                    "Недостаточно данных",
                                    systemImage: "waveform.path.ecg.rectangle",
                                    description: Text("Нужно минимум 2 недели данных для построения графика формы")
                                )
                                .frame(maxHeight: .infinity)
                            } else {
                                let allDaily = calculateDailyMetrics()
                                let filteredDaily = filterMetrics(allDaily)
                                let weeklyLoad = calculateWeeklyMetrics(allDaily)
                                let currentStatus = allDaily.last
                                
                                pmcTabViewContent(allDaily: allDaily, filteredDaily: filteredDaily, weeklyLoad: weeklyLoad, currentStatus: currentStatus)
                            }
                        } else if selectedTab == .hrv {
                            ScrollView(showsIndicators: false) {
                                readinessScoreFormView()
                                    .padding(.horizontal, 14)
                                    .padding(.top, 4)
                                    .padding(.bottom, 120)
                            }
                        } else if selectedTab == .powerCurve {
                            PowerCurveFormView()
                        } else if selectedTab == .dynamics {
                            ScrollView(showsIndicators: false) {
                                runningDynamicsFormView()
                                    .padding(.horizontal, 14)
                                    .padding(.top, 4)
                                    .padding(.bottom, 120)
                            }
                        } else if selectedTab == .weather {
                            WeatherAnalyticsView()
                        }
                }
            }
        }
        .navigationTitle("Форма")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $isShowingPlanner) {
            TrainingPlannerView()
        }
        .sheet(isPresented: $isShowingAddPlannedWorkout) {
            AddPlannedWorkoutSheet()
        }
        .onAppear {
            drawTracker = 0.0
            withAnimation(DesignTokens.Motion.content(reduceMotion: reduceMotion)) {
                drawTracker = 1.0
            }
            if selectedTab == .hrv {
                loadReadinessData()
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .hrv {
                loadReadinessData()
            }
        }
        .onChange(of: readinessPeriodDays) { _, _ in
            loadReadinessData()
        }
    }

    // MARK: - PMC Line Chart Section
    private func pmcChartSection(_ metrics: [DailyMetrics]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Управление формой")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                
                // Legend
                HStack(spacing: 8) {
                    legendTile(title: "CTL", color: Color.accentPrimary)
                    legendTile(title: "ATL", color: Color(hex: "C8304F"))
                    legendTile(title: "TSB", color: Color(hex: "C4923A"))
                }
            }
            
            // Hover Tooltip Info
            if let selectedDate, let point = metrics.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                HStack(spacing: 16) {
                    Text(point.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    tooltipMetric(title: "CTL", value: point.ctl, color: Color.accentPrimary)
                    tooltipMetric(title: "ATL", value: point.atl, color: Color(hex: "C8304F"))
                    tooltipMetric(title: "TSB", value: point.tsb, color: tsbColor(point.tsb))
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let current = metrics.last {
                // Default showing current today values
                HStack(spacing: 16) {
                    Text("Сегодня")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.textSecondaryReadable)
                    Spacer()
                    tooltipMetric(title: "CTL", value: current.ctl, color: Color.accentPrimary)
                    tooltipMetric(title: "ATL", value: current.atl, color: Color(hex: "C8304F"))
                    tooltipMetric(title: "TSB", value: current.tsb, color: tsbColor(current.tsb))
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // PMC Chart
            if !isRunningTests {
                Chart {
                    ForEach(plannedWeeks) { week in
                        RuleMark(x: .value("Неделя", week.startDate))
                            .foregroundStyle(Color.white.opacity(0.06))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    
                    ForEach(metrics) { point in
                        // CTL Line (Fitness)
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("CTL", point.ctl)
                        )
                        .foregroundStyle(Color.accentPrimary)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(point.isPrediction ? StrokeStyle(lineWidth: 2, dash: [4, 4]) : StrokeStyle(lineWidth: 2))

                        // ATL Line (Fatigue)
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("ATL", point.atl)
                        )
                        .foregroundStyle(Color(hex: "C8304F"))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(point.isPrediction ? StrokeStyle(lineWidth: 2, dash: [4, 4]) : StrokeStyle(lineWidth: 2))
                        
                        // TSB Line (Form - dashed gold)
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("TSB", point.tsb)
                        )
                        .foregroundStyle(Color(hex: "C4923A"))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(point.isPrediction ? StrokeStyle(lineWidth: 1.5, dash: [3, 3]) : StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        
                        // TSB Area (Form - shaded under/above zero)
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("TSB", point.tsb)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    point.tsb >= 0 ? Color.accentPrimary.opacity(0.08) : Color(hex: "C8304F").opacity(0.08),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Selection Rule Indicator
                    if let selectedDate {
                        RuleMark(x: .value("Selected Date", selectedDate))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .offset(y: 0)
                            .annotation(position: .top) {
                                Circle()
                                    .fill(Color.accentPrimary)
                                    .frame(width: 6, height: 6)
                            }
                    }
                }
                .frame(height: 145)
                .chartXSelection(value: $selectedDate)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Color.white.opacity(0.03))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(.defaultDigits))
                            .font(.system(size: 8))
                            .foregroundStyle(Color.textSecondaryReadable)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Color.white.opacity(0.03))
                        AxisValueLabel()
                            .font(.system(size: 8))
                            .foregroundStyle(Color.textSecondaryReadable)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 145)
                    .overlay(
                        Text("График управления нагрузкой")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .padding(12)
        .liquidGlassCard()
    }

    private func legendTile(title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 14, height: 2)
                .shadow(color: color.opacity(0.6), radius: 3)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.textSecondaryReadable)
        }
    }

    private func tooltipMetric(title: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.textTertiaryReadable)
            Text(String(format: "%.1f", value))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private func metricsRowSection(_ today: DailyMetrics) -> some View {
        let tsbValue = today.tsb
        let tsbColor = tsbValue > 5 ? Color.accentPrimary : (tsbValue > -10 ? Color(hex: "C4923A") : Color(hex: "C8304F"))
        let tsbLabel = tsbValue > 5 ? "Свежий" : (tsbValue > -10 ? "Умеренно" : "Перегрузка")
        
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            MetricDataCard(
                title: "Фитнес CTL",
                value: String(format: "%.1f", today.ctl),
                detail: "за 42 дня",
                color: Color.accentPrimary
            )
            MetricDataCard(
                title: "Усталость ATL",
                value: String(format: "%.1f", today.atl),
                detail: "за 7 дней",
                color: Color.ruby
            )
            
            MetricDataCard(
                title: "Форма TSB",
                value: String(format: "%+.1f", tsbValue),
                detail: tsbLabel,
                color: tsbColor
            )
        }
    }

    // MARK: - TSB Interpretation Section
    private func tsbInterpretationSection(_ today: DailyMetrics) -> some View {
        let tsbValue = today.tsb
        let tsbColor = tsbValue > 5 ? Color.accentPrimary : (tsbValue > -10 ? Color(hex: "C4923A") : Color(hex: "C8304F"))
        let tsbText = tsbValue > 10 ? "Свежий — готов к стартам" : (tsbValue > 0 ? "Хорошая форма" : (tsbValue > -10 ? "Умеренная усталость" : "Высокая нагрузка"))
        
        return VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("СОСТОЯНИЕ СЕГОДНЯ")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Color.textSecondaryReadable)
                    
                    Text(tsbText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tsbColor)
                        .shadow(color: tsbColor.opacity(0.4), radius: 6)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%+.0f", tsbValue))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(tsbColor)
                        .shadow(color: tsbColor.opacity(0.5), radius: 8)
                    
                    Text("TSB")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.textTertiaryReadable)
                }
            }
            
            Text(tsbStatusDescription(today.tsb))
                .font(.system(size: 11))
                .lineSpacing(2)
                .foregroundStyle(Color.textSecondaryReadable)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .liquidGlassCard(tint: tsbValue > 0 ? .emerald : .neutral)
    }

    // MARK: - Weekly Load Bar Chart Section
    private func weeklyLoadSection(_ weekly: [WeeklyMetric]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Недельная нагрузка")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            
            if !isRunningTests {
                Chart {
                    ForEach(weekly) { week in
                        BarMark(
                            x: .value("Week", week.weekStart),
                            y: .value("TRIMP Load", week.totalLoad)
                        )
                        .foregroundStyle(Color.accentPrimary.gradient)
                    }
                }
                .frame(height: 110)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.system(size: 8))
                            .foregroundStyle(Color.textSecondaryReadable)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Color.white.opacity(0.03))
                        AxisValueLabel()
                            .font(.system(size: 8))
                            .foregroundStyle(Color.textSecondaryReadable)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 110)
                    .overlay(
                        Text("График недельной нагрузки")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .padding(12)
        .liquidGlassCard()
    }

    // MARK: - Sports Science Computations

    private func calculateDailyMetrics() -> [DailyMetrics] {
        let sorted = activities.sorted { $0.startDate < $1.startDate }
        guard let firstDate = sorted.first?.startDate else { return [] }
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var dailyLoads: [String: Double] = [:]
        for act in sorted {
            let key = dateFormatter.string(from: act.startDate)
            dailyLoads[key] = (dailyLoads[key] ?? 0.0) + act.trainingLoad
        }
        
        var metrics: [DailyMetrics] = []
        var ctl = 0.0
        var atl = 0.0
        
        let startDay = calendar.startOfDay(for: firstDate)
        let endActualDay = calendar.startOfDay(for: .now)
        
        // Find if there are future planned training weeks
        let lastPlannedDate = plannedWeeks.last?.startDate.addingTimeInterval(86400 * 6) ?? .now
        let lastPlannedWorkoutDate = plannedWorkouts.last?.date ?? .now
        let defaultForecastEnd = calendar.date(byAdding: .day, value: 30, to: .now) ?? .now
        let endDay = max(endActualDay, calendar.startOfDay(for: lastPlannedDate), calendar.startOfDay(for: lastPlannedWorkoutDate), calendar.startOfDay(for: defaultForecastEnd))
        
        var currentDay = startDay
        while currentDay <= endDay {
            let isPrediction = currentDay > endActualDay
            let dayLoad: Double
            
            if !isPrediction {
                let key = dateFormatter.string(from: currentDay)
                dayLoad = dailyLoads[key] ?? 0.0
            } else {
                let dayStart = calendar.startOfDay(for: currentDay)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                let dayPlanned = plannedWorkouts.filter { $0.date >= dayStart && $0.date < dayEnd && !$0.isCompleted }
                
                if !dayPlanned.isEmpty {
                    dayLoad = dayPlanned.reduce(0.0) { $0 + $1.plannedTSS }
                } else {
                    // Estimate planned daily load for future date based on plan
                    if let matchingWeek = plannedWeeks.first(where: { week in
                        let wStart = calendar.startOfDay(for: week.startDate)
                        let wEnd = calendar.date(byAdding: .day, value: 7, to: wStart)!
                        return currentDay >= wStart && currentDay < wEnd
                    }) {
                        let weeklyLoad = ((matchingWeek.targetVolumeMeters / 1000.0) * 7.0) + (matchingWeek.targetCyclingHours * 50.0)
                        dayLoad = weeklyLoad / 7.0
                    } else {
                        dayLoad = 0.0
                    }
                }
            }
            
            // Standard performance management calculations
            ctl += (dayLoad - ctl) / 42.0
            atl += (dayLoad - atl) / 7.0
            let tsb = ctl - atl
            
            metrics.append(DailyMetrics(date: currentDay, ctl: ctl, atl: atl, tsb: tsb, load: dayLoad, isPrediction: isPrediction))
            
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }
        
        return metrics
    }

    private func calculateWeeklyMetrics(_ daily: [DailyMetrics]) -> [WeeklyMetric] {
        guard !daily.isEmpty else { return [] }
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: daily) { day in
            calendar.dateInterval(of: .weekOfYear, for: day.date)?.start ?? day.date
        }
        
        var weekly: [WeeklyMetric] = []
        for (weekStart, days) in grouped {
            let sum = days.reduce(0.0) { $0 + $1.load }
            weekly.append(WeeklyMetric(weekStart: weekStart, totalLoad: sum))
        }
        
        return weekly.sorted { $0.weekStart < $1.weekStart }
    }

    private func filterMetrics(_ metrics: [DailyMetrics]) -> [DailyMetrics] {
        let baseFiltered: [DailyMetrics] = {
            guard let daysCount = selectedPeriod.daysCount else { return metrics }
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysCount, to: .now) ?? .now
            return metrics.filter { $0.date >= cutoffDate }
        }()
        
        // Slice based on drawTracker animation
        let targetCount = Int(Double(baseFiltered.count) * drawTracker)
        return Array(baseFiltered.prefix(max(1, targetCount)))
    }

    private func filterWeekly(_ weekly: [WeeklyMetric]) -> [WeeklyMetric] {
        guard let daysCount = selectedPeriod.daysCount else { return weekly }
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysCount, to: .now) ?? .now
        return weekly.filter { $0.weekStart >= cutoffDate }
    }

    // MARK: - Sports Science Helpers

    private func tsbColor(_ tsb: Double) -> Color {
        if tsb > 10 { return .green }
        if tsb >= 0 { return .blue }
        if tsb >= -10 { return .orange }
        if tsb >= -30 { return .red }
        return .purple
    }

    private func tsbIcon(_ tsb: Double) -> String {
        if tsb > 10 { return "sparkles" }
        if tsb >= 0 { return "checkmark.circle.fill" }
        if tsb >= -10 { return "hourglass" }
        if tsb >= -30 { return "exclamationmark.triangle.fill" }
        return "exclamationmark.shield.fill"
    }

    private func tsbStatusTitle(_ tsb: Double) -> String {
        if tsb > 10 { return "Свежесть и готовность к старту" }
        if tsb >= 0 { return "Оптимальная форма" }
        if tsb >= -10 { return "Умеренная тренировочная усталость" }
        if tsb >= -30 { return "Высокая тренировочная нагрузка" }
        return "Критический риск перетренированности"
    }

    private func tsbStatusDescription(_ tsb: Double) -> String {
        if tsb > 10 {
            return "Вы полностью восстановились. Подходящий момент для старта, проверки рекорда или ключевой тренировки."
        } else if tsb >= 0 {
            return "Хороший баланс формы и усталости. Организм готов к продуктивной развивающей тренировке."
        } else if tsb >= -10 {
            return "Обычное состояние активного тренировочного периода. Продолжайте сочетать нагрузку с восстановлением."
        } else if tsb >= -30 {
            return "Усталость превышает восстановление. Запланируйте разгрузочную неделю или несколько дней отдыха."
        } else {
            return "Критический уровень усталости. Высокий риск травмы или перетренированности: снизьте нагрузку и отдохните."
        }
    }

    // MARK: - Readiness Score & HRV Analytics Helpers
    
    private func loadReadinessData() {
        isLoadingReadiness = true
        Task {
            let hrv = await HealthKitManager.shared.fetchHRVSDNN()
            let sleep = await HealthKitManager.shared.fetchSleepDetailsLastNight()
            let resting = await HealthKitManager.shared.fetchRestingHR()
            
            let ctlList = getCtlMap()
            let atlList = getAtlMap()
            
            let hardWorkoutDates = Set(activities.filter { $0.trainingLoad > 100 || $0.trimp > 100 }.map { Calendar.current.startOfDay(for: $0.startDate) })
            let history = await HealthKitManager.shared.fetchReadinessHistory(
                daysCount: readinessPeriodDays,
                ctlList: ctlList,
                atlList: atlList,
                hardWorkoutDates: hardWorkoutDates
            )
            
            await MainActor.run {
                self.hrvToday = hrv.today
                self.hrvBaseline = hrv.baseline30Day
                self.sleepHoursToday = sleep.total
                self.sleepDeepHoursToday = sleep.deep
                self.restingHRToday = resting
                self.readinessHistory = history
                self.isLoadingReadiness = false
            }
        }
    }
    
    private func getCtlMap() -> [Date: Double] {
        let calendar = Calendar.current
        var ctlList: [Date: Double] = [:]
        let allMetrics = calculateDailyMetrics()
        for m in allMetrics {
            ctlList[calendar.startOfDay(for: m.date)] = m.ctl
        }
        return ctlList
    }
    
    private func getAtlMap() -> [Date: Double] {
        let calendar = Calendar.current
        var atlList: [Date: Double] = [:]
        let allMetrics = calculateDailyMetrics()
        for m in allMetrics {
            atlList[calendar.startOfDay(for: m.date)] = m.atl
        }
        return atlList
    }
    
    private func readinessColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 40 { return .yellow }
        return .red
    }
    
    private func readinessAdvice(_ score: Int) -> String {
        if score >= 80 {
            return "Отличный день для интервалов! Ваша готовность \(score)%. Организм полностью адаптирован."
        } else if score >= 40 {
            return "Ваша готовность \(score)%. Рекомендуется базовая выносливость или умеренный бег."
        } else {
            return "Ваша готовность \(score)% (высокое утомление). Лучше запланировать день отдыха или легкую разминку."
        }
    }
    
    private func tsbTaperMessage(_ tsb: Double) -> String {
        if tsb > 15 { return "Избыточная свежесть" }
        if tsb > 5 { return "Идеально для старта" }
        if tsb >= -5 { return "Хорошая готовность" }
        if tsb >= -15 { return "Небольшая усталость" }
        return "Высокая усталость"
    }
    
    @ViewBuilder
    private func readinessScoreFormView() -> some View {
        VStack(spacing: 20) {
            if isLoadingReadiness {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Загрузка данных готовности...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
                .padding(.vertical, 80)
            } else {
                // 1. circular progress readiness score
                let summary = DashboardViewModel.summary(from: activities)
                let daysSinceHard = {
                    let hardActivity = activities.first { $0.trainingLoad > 100 || $0.trimp > 100 }
                    guard let hardActivity else { return 30 }
                    let calendar = Calendar.current
                    let startOfToday = calendar.startOfDay(for: Date())
                    let startOfWorkout = calendar.startOfDay(for: hardActivity.startDate)
                    return max(0, calendar.dateComponents([.day], from: startOfWorkout, to: startOfToday).day ?? 30)
                }()
                
                let details = HealthKitManager.shared.calculateDetailedReadiness(
                    hrvToday: hrvToday,
                    hrvBaseline: hrvBaseline,
                    sleepTotalHours: sleepHoursToday,
                    sleepDeepHours: sleepDeepHoursToday,
                    tsb: summary.tsb,
                    daysSinceLastHardWorkout: daysSinceHard
                )
                let currentReadiness = details.score
                
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(.tertiary.opacity(0.3), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(Double(currentReadiness) / 100.0))
                            .stroke(readinessColor(currentReadiness).gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                        
                        VStack {
                            Text("\(currentReadiness)%")
                                .font(.system(size: 32, weight: .bold))
                            Text(details.category)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(readinessColor(currentReadiness))
                        }
                    }
                    
                    Text(details.explanation)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .liquidGlassCard(cornerRadius: 16)
                
                // 2. Metrics grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    let deepVal = sleepDeepHoursToday ?? ((sleepHoursToday ?? 7.5) * 0.2)
                    ReadinessMetricCard(
                        title: "Сон (Глубокий / Всего)",
                        value: sleepHoursToday != nil ? String(format: "%.1f ч / %.1f ч", deepVal, sleepHoursToday!) : "-- ч",
                        subtitle: "Цель гл: 1.5 ч",
                        icon: "bed.double.fill",
                        iconColor: .purple
                    )
                    
                    ReadinessMetricCard(
                        title: "Вариабельность ритма (ВСР)",
                        value: hrvToday != nil ? String(format: "%.0f мс", hrvToday!) : "-- мс",
                        subtitle: hrvBaseline != nil ? String(format: "База: %.0f мс", hrvBaseline!) : "База: --",
                        icon: "heart.text.square.fill",
                        iconColor: .red
                    )
                    
                    ReadinessMetricCard(
                        title: "Дни отдыха",
                        value: daysSinceHard < 30 ? "\(daysSinceHard) дн" : "Отдых >30 дн",
                        subtitle: daysSinceHard == 0 ? "Сегодня тяжелая" : (daysSinceHard == 1 ? "Вчера тяжелая" : "Восстановление"),
                        icon: "calendar.badge.clock",
                        iconColor: .green
                    )
                    
                    ReadinessMetricCard(
                        title: "Форма (TSB)",
                        value: String(format: "%.0f", summary.tsb),
                        subtitle: tsbTaperMessage(summary.tsb),
                        icon: "waveform.path.ecg.rectangle.fill",
                        iconColor: .blue
                    )
                }
                
                // 3. Period selector
                HStack(spacing: 8) {
                    ForEach([7, 30], id: \.self) { days in
                        Button {
                            HapticManager.trigger(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                readinessPeriodDays = days
                            }
                        } label: {
                            Text(days == 7 ? "7 дней" : "30 дней")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(readinessPeriodDays == days ? Color.accentPrimary.opacity(0.12) : Color.white.opacity(0.04))
                                .foregroundColor(readinessPeriodDays == days ? Color.accentPrimary : Color.textSecondaryReadable)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(readinessPeriodDays == days ? Color.accentPrimary.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.top, 8)
                
                // 4. Trend Charts
                VStack(alignment: .leading, spacing: 8) {
                    Text("Тренд готовности")
                        .font(.headline)
                        .padding(.horizontal, 4)
                    
                    Group {
                        if !isRunningTests {
                            Chart {
                                ForEach(readinessHistory) { point in
                                    LineMark(
                                        x: .value("Дата", point.date, unit: .day),
                                        y: .value("Готовность", point.readinessScore)
                                    )
                                    .foregroundStyle(Color.blue.gradient)
                                    .interpolationMethod(.catmullRom)
                                    .accessibilityLabel("Индекс готовности")
                                    .accessibilityValue("Готовность \(point.readinessScore)% на \(formatChartDate(point.date))")
                                    
                                    PointMark(
                                        x: .value("Дата", point.date, unit: .day),
                                        y: .value("Готовность", point.readinessScore)
                                    )
                                    .foregroundStyle(readinessColor(point.readinessScore))
                                }
                            }
                            .frame(height: 180)
                            .chartYScale(domain: 0...100)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day, count: readinessPeriodDays == 7 ? 1 : 5)) { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.day().month())
                                }
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 180)
                                .overlay(
                                    Text("График тренда готовности")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                    .padding()
                    .liquidGlassCard(cornerRadius: 16)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Динамика ВСР и базовый диапазон")
                        .font(.headline)
                        .padding(.horizontal, 4)
                    
                    Group {
                        if !isRunningTests {
                            Chart {
                                ForEach(readinessHistory) { point in
                                    // SWC Corridor: baseline - 5 to baseline + 5
                                    AreaMark(
                                        x: .value("Дата", point.date, unit: .day),
                                        yStart: .value("Нижняя граница", point.hrvBaseline - 5),
                                        yEnd: .value("Верхняя граница", point.hrvBaseline + 5)
                                    )
                                    .foregroundStyle(Color.secondary.opacity(0.15))
                                    
                                    LineMark(
                                        x: .value("Дата", point.date, unit: .day),
                                        y: .value("Базовая ВСР", point.hrvBaseline)
                                    )
                                    .foregroundStyle(Color.secondary)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                    .accessibilityLabel("Базовая ВСР")
                                    .accessibilityValue("Базовый показатель ВСР \(Int(point.hrvBaseline)) мс на \(formatChartDate(point.date))")
                                    
                                    LineMark(
                                        x: .value("Дата", point.date, unit: .day),
                                        y: .value("ВСР", point.hrv)
                                    )
                                    .foregroundStyle(Color.red.gradient)
                                    .interpolationMethod(.catmullRom)
                                    .accessibilityLabel("Текущая ВСР")
                                    .accessibilityValue("Текущий показатель ВСР \(Int(point.hrv)) мс на \(formatChartDate(point.date))")
                                    
                                    PointMark(
                                        x: .value("Дата", point.date, unit: .day),
                                        y: .value("ВСР", point.hrv)
                                    )
                                    .foregroundStyle(Color.red)
                                }
                            }
                            .frame(height: 180)
                            .chartYScale(domain: 20...120)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day, count: readinessPeriodDays == 7 ? 1 : 5)) { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.day().month())
                                }
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 180)
                                .overlay(
                                    Text("Тренд ВСР и коридор SWC")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                    .padding()
                    .liquidGlassCard(cornerRadius: 16)
                }
            }
        }
    }
    
    struct MonthlyDynamics: Identifiable {
        let id = UUID()
        let monthStart: Date
        let avgCadence: Double
        let avgStride: Double
    }
    
    private func calculateMonthlyDynamics() -> [MonthlyDynamics] {
        let calendar = Calendar.current
        let runs = activities.filter { $0.sportType.lowercased() == "run" && ($0.averageCadence ?? 0.0) > 0.0 }
        
        let grouped = Dictionary(grouping: runs) { run -> Date in
            let components = calendar.dateComponents([.year, .month], from: run.startDate)
            return calendar.date(from: components) ?? Date()
        }
        
        return grouped.map { (monthDate, monthRuns) -> MonthlyDynamics in
            let cadSum = monthRuns.reduce(0.0) { $0 + ($1.averageCadence ?? 0.0) }
            let strideSum = monthRuns.reduce(0.0) { $0 + ($1.averageStrideLength ?? 0.0) }
            let count = Double(monthRuns.count)
            return MonthlyDynamics(
                monthStart: monthDate,
                avgCadence: count > 0 ? cadSum / count : 0.0,
                avgStride: count > 0 ? strideSum / count : 0.0
            )
        }.sorted { $0.monthStart < $1.monthStart }
    }
    
    private func runningDynamicsFormView() -> some View {
        let monthlyData = calculateMonthlyDynamics()
        let isRussian = AppLanguage.isRussian
        let isMetric = activeUserSettings.isMetric
        let strideMultiplier = isMetric ? 1.0 : 3.28084
        let strideUnit = isRussian ? (isMetric ? "м" : "фт") : (isMetric ? "m" : "ft")
        
        return VStack(spacing: 24) {
            if monthlyData.isEmpty {
                ContentUnavailableView(
                    isRussian ? "Нет данных динамики бега" : "No Running Dynamics Data",
                    systemImage: "figure.run",
                    description: Text(isRussian ? "Для построения трендов необходимы пробежки с данными о каденсе." : "Need running activities with cadence data to plot trends.")
                )
                .frame(maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(isRussian ? "Каденс по месяцам" : "Monthly Average Cadence")
                        .font(.headline)
                        .padding(.horizontal, 4)
                    
                    Group {
                        if !isRunningTests {
                            Chart {
                                ForEach(monthlyData) { point in
                                    LineMark(
                                        x: .value(isRussian ? "Месяц" : "Month", point.monthStart, unit: .month),
                                        y: .value(isRussian ? "Каденс" : "Cadence", point.avgCadence)
                                    )
                                    .foregroundStyle(Color.blue.gradient)
                                    .interpolationMethod(.catmullRom)
                                    .accessibilityLabel(isRussian ? "Средний каденс" : "Average Cadence")
                                    .accessibilityValue("\(isRussian ? "Средний каденс" : "Average Cadence") \(Int(point.avgCadence)) шагов/мин на \(formatMonthDate(point.monthStart, isRussian: isRussian))")
                                    
                                    PointMark(
                                        x: .value(isRussian ? "Месяц" : "Month", point.monthStart, unit: .month),
                                        y: .value(isRussian ? "Каденс" : "Cadence", point.avgCadence)
                                    )
                                    .foregroundStyle(Color.blue)
                                }
                            }
                            .frame(height: 180)
                            .chartYScale(domain: 150...200)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                                }
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 180)
                                .overlay(
                                    Text("Средний каденс (за месяц)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                    .padding()
                    .liquidGlassCard(cornerRadius: 16)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(isRussian ? "Длина шага по месяцам" : "Monthly Average Stride Length")
                        .font(.headline)
                        .padding(.horizontal, 4)
                    
                    Group {
                        if !isRunningTests {
                            Chart {
                                ForEach(monthlyData) { point in
                                    BarMark(
                                        x: .value(isRussian ? "Месяц" : "Month", point.monthStart, unit: .month),
                                        y: .value(isRussian ? "Длина шага" : "Stride Length", point.avgStride * strideMultiplier)
                                    )
                                    .foregroundStyle(Color.green.gradient)
                                }
                            }
                            .frame(height: 180)
                            .chartYScale(domain: (isMetric ? 0.6 : 2.0)...(isMetric ? 1.6 : 5.0))
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                                }
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 180)
                                .overlay(
                                    Text("Средняя длина шага (за месяц)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                    .padding()
                    .liquidGlassCard(cornerRadius: 16)
                }
                
                // A summary block showing overall averages
                let overallCadence = monthlyData.reduce(0.0) { $0 + $1.avgCadence } / Double(monthlyData.count)
                let overallStride = monthlyData.reduce(0.0) { $0 + $1.avgStride } / Double(monthlyData.count)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(isRussian ? "Общая сводка" : "Overall Summary")
                        .font(.headline)
                        .padding(.horizontal, 4)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isRussian ? "Каденс" : "Cadence")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f SPM", overallCadence))
                                .font(.title2.bold())
                            let zone = RunningDynamicsEngine.classifyCadence(overallCadence)
                            Text(localizedZoneText(zone, isRussian: isRussian))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(zoneColor(zone))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .liquidGlassCard(cornerRadius: 12)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isRussian ? "Длина шага" : "Stride Length")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f %@", overallStride * strideMultiplier, strideUnit))
                                .font(.title2.bold())
                            let zone = RunningDynamicsEngine.classifyStrideLength(overallStride)
                            Text(localizedZoneText(zone, isRussian: isRussian))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(zoneColor(zone))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .liquidGlassCard(cornerRadius: 12)
                    }
                }
            }
        }
    }
    
    private func zoneColor(_ zone: DynamicsZone) -> Color {
        switch zone {
        case .optimal: return .purple
        case .good: return .blue
        case .fair: return .green
        case .poor: return .red
        }
    }

    private func localizedZoneText(_ zone: DynamicsZone, isRussian: Bool) -> String {
        switch zone {
        case .optimal: return isRussian ? "Отлично" : "Optimal"
        case .good: return isRussian ? "Хорошо" : "Good"
        case .fair: return isRussian ? "Удовл." : "Fair"
        case .poor: return isRussian ? "Низкий" : "Poor"
        }
    }
    
    private func formatChartDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "d MMMM"
        df.locale = Locale(identifier: "ru_RU")
        return df.string(from: date)
    }
    
    private func formatMonthDate(_ date: Date, isRussian: Bool) -> String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        df.locale = Locale(identifier: isRussian ? "ru_RU" : "en_US")
        return df.string(from: date)
    }

    // MARK: - Forecast & Planning Helpers

    private func forecastPlannerSection() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(AppLanguage.isRussian ? "Прогноз и Планировщик" : "Forecast & Planner")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    isShowingAddPlannedWorkout = true
                } label: {
                    Label {
                        Text(AppLanguage.isRussian ? "Запланировать" : "Plan")
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.orange)
                }
            }
            
            let futureWorkouts = plannedWorkouts.filter { !$0.isCompleted && $0.date > Date() }
            
            if futureWorkouts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(.gray.opacity(0.5))
                    Text(AppLanguage.isRussian ? "Нет запланированных тренировок" : "No planned workouts")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.gray)
                    Text(AppLanguage.isRussian ? "Добавьте тренировки на будущие даты, чтобы смоделировать изменения CTL/ATL/TSB." : "Add future activities to model CTL/ATL/TSB fatigue changes.")
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                .cornerRadius(12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(futureWorkouts) { workout in
                            plannedWorkoutCard(for: workout)
                        }
                    }
                }
            }
        }
        .padding(12)
        .liquidGlassCard(cornerRadius: 12)
    }

    @ViewBuilder
    private func plannedWorkoutCard(for workout: PlannedWorkout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: sportIcon(for: workout.sportType))
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                Spacer()
                
                Button(role: .destructive) {
                    modelContext.delete(workout)
                    try? modelContext.save()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
            
            Text(workout.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            HStack {
                Text(formatDistance(workout.plannedDistanceMeters))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.0f TSS", workout.plannedTSS))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Button {
                completePlannedWorkout(workout)
            } label: {
                Text(AppLanguage.isRussian ? "Выполнить" : "Complete")
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.orange.gradient)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 150)
        .liquidGlassCard(cornerRadius: 10)
    }

    private func sportIcon(for sport: String) -> String {
        switch sport {
        case "Run": return "figure.run"
        case "Ride": return "bicycle"
        case "Walk": return "figure.walk"
        case "Swim": return "figure.pool.swim"
        default: return "figure.mixed.cardio"
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        let isMetric = activeUserSettings.isMetric
        let divider = isMetric ? 1000.0 : 1609.344
        let unit = isMetric ? "км" : "миль"
        return String(format: "%.1f %@", meters / divider, unit)
    }

    private func completePlannedWorkout(_ workout: PlannedWorkout) {
        workout.isCompleted = true
        
        let newActivity = Activity(
            stravaId: Int64.random(in: 100000000...999999999),
            sportType: workout.sportType,
            name: workout.title,
            startDate: workout.date,
            distanceMeters: workout.plannedDistanceMeters,
            movingTime: workout.plannedDurationSeconds,
            elapsedTime: workout.plannedDurationSeconds,
            elevationGain: 0.0,
            averageHeartRate: nil,
            averagePower: nil,
            averageCadence: nil,
            averageSpeed: workout.plannedDurationSeconds > 0 ? (workout.plannedDistanceMeters / workout.plannedDurationSeconds) : 0.0,
            encodedPolyline: nil,
            trimp: workout.plannedTSS,
            trainingLoad: workout.plannedTSS,
            startLatitude: nil,
            startLongitude: nil
        )
        
        modelContext.insert(newActivity)
        try? modelContext.save()
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// Custom AreaBackground helper to avoid SwiftUI area shape styling issues
private struct AreaBackground {
    static func gradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct ReadinessMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor.gradient)
                    .font(.title3)
                Spacer()
            }
            
            Text(value)
                .font(.title2.bold())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .liquidGlassCard(cornerRadius: 12)
    }
}

// MARK: - AddPlannedWorkoutSheet

struct AddPlannedWorkoutSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var userSettings: [UserSettings]
    
    @State private var date = Date().addingTimeInterval(86400) // tomorrow by default
    @State private var sportType = "Run"
    @State private var title = ""
    @State private var plannedDurationHours = 1
    @State private var plannedDurationMinutes = 0
    @State private var plannedDistance: Double = 10.0
    @State private var intensityFactor = 0.75
    @State private var manualTSS: Double = 50.0
    @State private var isManualTSS = false
    
    private var isMetric: Bool {
        userSettings.first?.isMetric ?? true
    }
    
    private var computedTSS: Double {
        let durationSeconds = Double(plannedDurationHours * 3600 + plannedDurationMinutes * 60)
        let tss = (durationSeconds * intensityFactor * intensityFactor * 100.0) / 3600.0
        return tss
    }
    
    private var finalTSS: Double {
        isManualTSS ? manualTSS : computedTSS
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(AppLanguage.isRussian ? "Детали тренировки" : "Workout Details") {
                    TextField(AppLanguage.isRussian ? "Название (например: Темп)" : "Title (e.g. Tempo)", text: $title)
                    
                    Picker(AppLanguage.isRussian ? "Вид спорта" : "Sport", selection: $sportType) {
                        Text(AppLanguage.isRussian ? "Бег" : "Run").tag("Run")
                        Text(AppLanguage.isRussian ? "Велосипед" : "Ride").tag("Ride")
                        Text(AppLanguage.isRussian ? "Ходьба" : "Walk").tag("Walk")
                        Text(AppLanguage.isRussian ? "Плавание" : "Swim").tag("Swim")
                    }
                    
                    DatePicker(AppLanguage.isRussian ? "Дата" : "Date", selection: $date, displayedComponents: .date)
                }
                
                Section(AppLanguage.isRussian ? "Объем" : "Volume") {
                    HStack {
                        Text(AppLanguage.isRussian ? "Длительность" : "Duration")
                        Spacer()
                        Picker("Часы", selection: $plannedDurationHours) {
                            ForEach(0...23, id: \.self) { hr in
                                Text("\(hr) ч").tag(hr)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Picker("Минуты", selection: $plannedDurationMinutes) {
                            ForEach(0...59, id: \.self) { min in
                                Text("\(min) м").tag(min)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(AppLanguage.isRussian ? "Дистанция" : "Distance")
                            Spacer()
                            Text(String(format: "%.1f %@", plannedDistance, isMetric ? "км" : "миль"))
                                .font(.subheadline.weight(.semibold))
                        }
                        Slider(value: $plannedDistance, in: 0...100, step: 0.5)
                    }
                }
                
                Section(AppLanguage.isRussian ? "Интенсивность и Нагрузка (TSS)" : "Intensity & Load (TSS)") {
                    Toggle(AppLanguage.isRussian ? "Ввести TSS вручную" : "Manual TSS Entry", isOn: $isManualTSS)
                        .tint(.orange)
                    
                    if !isManualTSS {
                        Picker(AppLanguage.isRussian ? "Интенсивность" : "Intensity Preset", selection: $intensityFactor) {
                            Text("Восстановление (IF 0.60)").tag(0.60)
                            Text("Аэробный темп (IF 0.75)").tag(0.75)
                            Text("Темповая работа (IF 0.85)").tag(0.85)
                            Text("Порог LTHR (IF 0.95)").tag(0.95)
                            Text("Интервалы VO2Max (IF 1.05)").tag(1.05)
                        }
                        .pickerStyle(.menu)
                        
                        HStack {
                            Text("Индекс интенсивности (IF):")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f", intensityFactor))
                                .font(.caption.weight(.bold))
                        }
                        
                        HStack {
                            Text(AppLanguage.isRussian ? "Расчетный TSS:" : "Calculated TSS:")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.0f", computedTSS))
                                .font(.title3.weight(.black))
                                .foregroundColor(.green)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Нагрузка (TSS)")
                                Spacer()
                                Text("\(Int(manualTSS))")
                                    .font(.headline)
                            }
                            Slider(value: $manualTSS, in: 10...300, step: 5)
                        }
                    }
                }
            }
            .navigationTitle(AppLanguage.isRussian ? "Запланировать тренировку" : "Plan Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(AppLanguage.isRussian ? "Отмена" : "Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppLanguage.isRussian ? "Сохранить" : "Save") {
                        savePlannedWorkout()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func savePlannedWorkout() {
        let durationSeconds = Double(plannedDurationHours * 3600 + plannedDurationMinutes * 60)
        let distanceMeters = plannedDistance * (isMetric ? 1000.0 : 1609.344)
        
        let workout = PlannedWorkout(
            date: Calendar.current.startOfDay(for: date).addingTimeInterval(12 * 3600),
            sportType: sportType,
            title: title,
            plannedDurationSeconds: durationSeconds,
            plannedDistanceMeters: distanceMeters,
            plannedTSS: finalTSS
        )
        
        modelContext.insert(workout)
        try? modelContext.save()
        
        dismiss()
    }
}
