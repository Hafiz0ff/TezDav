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
    
    enum FormTab: String, CaseIterable, Identifiable {
        case pmc = "PMC"
        case powerCurve = "Кривая мощности"
        var id: String { self.rawValue }
    }
    
    @State private var selectedTab: FormTab = .pmc
    @State private var selectedPeriod: Period = .threeMonths
    @State private var selectedDate: Date? = nil
    @State private var isShowingPlanner = false
    @State private var drawTracker = 0.0
    
    enum Period: String, CaseIterable, Identifiable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case all = "All"
        
        var id: String { self.rawValue }
        
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

    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    ContentUnavailableView(
                        "Нет тренировок",
                        systemImage: "waveform.path.ecg.rectangle",
                        description: Text("Импортируйте тренировки, чтобы начать анализ.")
                    )
                } else {
                    VStack(spacing: 0) {
                        Picker("Анализ", selection: $selectedTab) {
                            ForEach(FormTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        if selectedTab == .pmc {
                            let daysSpan = {
                                guard let first = activities.first?.startDate, let last = activities.last?.startDate else { return 0 }
                                return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: first), to: Calendar.current.startOfDay(for: last)).day ?? 0
                            }()
                            
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
                                
                                ScrollView {
                                    VStack(spacing: 24) {
                                        // Period Selector
                                        Picker("Period", selection: $selectedPeriod) {
                                            ForEach(Period.allCases) { period in
                                                Text(period.rawValue).tag(period)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                        
                                        // 1. Main PMC Line Chart
                                        pmcChartSection(filteredDaily)
                                        
                                        // 2. TSB Interpretation Card
                                        if let currentStatus {
                                            tsbInterpretationSection(currentStatus)
                                        }
                                        
                                        // 3. Weekly Load Bar Chart
                                        weeklyLoadSection(filterWeekly(weeklyLoad))
                                    }
                                    .padding()
                                }
                            }
                        } else {
                            PowerCurveFormView()
                        }
                    }
                    .navigationTitle(selectedTab == .pmc ? "Анализ формы" : "Кривая мощности")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                isShowingPlanner = true
                            } label: {
                                Image(systemName: "calendar.badge.clock")
                            }
                        }
                    }
                    .sheet(isPresented: $isShowingPlanner) {
                        TrainingPlannerView()
                    }
                    .onAppear {
                        drawTracker = 0.0
                        withAnimation(.easeOut(duration: 0.6)) {
                            drawTracker = 1.0
                        }
                    }
                }
            }
        }
    }

    // MARK: - PMC Line Chart Section
    private func pmcChartSection(_ metrics: [DailyMetrics]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Performance Management")
                    .font(.headline)
                Spacer()
                
                // Legend
                HStack(spacing: 8) {
                    legendTile(title: "CTL", color: .blue)
                    legendTile(title: "ATL", color: .red)
                    legendTile(title: "TSB", color: .green)
                }
            }
            
            // Hover Tooltip Info
            if let selectedDate, let point = metrics.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                HStack(spacing: 16) {
                    Text(point.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    tooltipMetric(title: "CTL", value: point.ctl, color: .blue)
                    tooltipMetric(title: "ATL", value: point.atl, color: .red)
                    tooltipMetric(title: "TSB", value: point.tsb, color: tsbColor(point.tsb))
                }
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else if let current = metrics.last {
                // Default showing current today values
                HStack(spacing: 16) {
                    Text("Today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    tooltipMetric(title: "CTL", value: current.ctl, color: .blue)
                    tooltipMetric(title: "ATL", value: current.atl, color: .red)
                    tooltipMetric(title: "TSB", value: current.tsb, color: tsbColor(current.tsb))
                }
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            // PMC Chart
            Chart {
                ForEach(plannedWeeks) { week in
                    RuleMark(x: .value("Неделя", week.startDate))
                        .foregroundStyle(.secondary.opacity(0.15))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                
                ForEach(metrics) { point in
                    // CTL Line (Fitness)
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("CTL", point.ctl)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(point.isPrediction ? StrokeStyle(lineWidth: 2, dash: [4, 4]) : StrokeStyle(lineWidth: 2))

                    // ATL Line (Fatigue)
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("ATL", point.atl)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(point.isPrediction ? StrokeStyle(lineWidth: 2, dash: [4, 4]) : StrokeStyle(lineWidth: 2))
                    
                    // TSB Area (Form - shaded under/above zero)
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("TSB", point.tsb)
                    )
                    .foregroundStyle(
                        AreaBackground.gradient(point.tsb >= 0 ? .green.opacity(0.10) : .orange.opacity(0.10))
                    )
                    .interpolationMethod(.catmullRom)
                }
                
                // Selection Rule Indicator
                if let selectedDate {
                    RuleMark(x: .value("Selected Date", selectedDate))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .offset(y: 0)
                        .annotation(position: .top) {
                            Circle()
                                .fill(.primary)
                                .frame(width: 6, height: 6)
                        }
                }
            }
            .frame(height: 220)
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(.defaultDigits))
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func legendTile(title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func tooltipMetric(title: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(String(format: "%.1f", value))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
        }
    }

    // MARK: - TSB Interpretation Section
    private func tsbInterpretationSection(_ today: DailyMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: tsbIcon(today.tsb))
                    .font(.title2)
                    .foregroundStyle(tsbColor(today.tsb))
                Text(tsbStatusTitle(today.tsb))
                    .font(.headline)
            }
            
            Text(tsbStatusDescription(today.tsb))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
            
            // Mini progress bars representing Fitness (CTL) and Fatigue (ATL) balance
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fitness (CTL)").font(.caption).foregroundStyle(.secondary)
                    Text(String(format: "%.1f", today.ctl)).font(.headline.weight(.semibold)).foregroundStyle(.blue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Fatigue (ATL)").font(.caption).foregroundStyle(.secondary)
                    Text(String(format: "%.1f", today.atl)).font(.headline.weight(.semibold)).foregroundStyle(.red)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Weekly Load Bar Chart Section
    private func weeklyLoadSection(_ weekly: [WeeklyMetric]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Training Load")
                .font(.headline)
            
            Chart {
                ForEach(weekly) { week in
                    BarMark(
                        x: .value("Week", week.weekStart),
                        y: .value("TRIMP Load", week.totalLoad)
                    )
                    .foregroundStyle(.blue.gradient)
                }
            }
            .frame(height: 140)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
        let endDay = max(endActualDay, calendar.startOfDay(for: lastPlannedDate))
        
        var currentDay = startDay
        while currentDay <= endDay {
            let isPrediction = currentDay > endActualDay
            let dayLoad: Double
            
            if !isPrediction {
                let key = dateFormatter.string(from: currentDay)
                dayLoad = dailyLoads[key] ?? 0.0
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
        if tsb > 10 { return "Fresh & Ready to Race" }
        if tsb >= 0 { return "Optimal Form (Base Mode)" }
        if tsb >= -10 { return "Moderate Training Fatigue" }
        if tsb >= -30 { return "High Training Overload" }
        return "Critical Overtraining Risk"
    }

    private func tsbStatusDescription(_ tsb: Double) -> String {
        if tsb > 10 {
            return "You are fully fresh and recovered. Perfect time to race, test your records, or perform a key training session."
        } else if tsb >= 0 {
            return "Excellent balance between fitness and fatigue. Your body is ready for productive developmental workouts."
        } else if tsb >= -10 {
            return "Standard active training state. You are accumulating fitness. Keep balancing workouts with recovery."
        } else if tsb >= -30 {
            return "Your fatigue exceeds recovery. Plan a recovery week or complete rest days to let your body adapt."
        } else {
            return "Critical fatigue level! Extremely high risk of injury or overtraining syndrome. Settle down and rest immediately."
        }
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
