import SwiftData
import SwiftUI

struct TrainingPlannerView: View {
    @Query(sort: \TrainingWeek.startDate, order: .forward) private var plannedWeeks: [TrainingWeek]
    @Query(sort: \Activity.startDate, order: .forward) private var activities: [Activity]
    @Query private var userSettings: [UserSettings]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Auto-generation form state
    @State private var targetRaceDate = Date().addingTimeInterval(86400 * 30 * 3) // default 3 months out
    @State private var currentRunningVolumeKm: Double = 30.0
    @State private var currentCyclingHours: Double = 3.0
    @State private var selectedWeekId: String? = nil
    
    var activeSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }
    
    // AI coach calculations
    private var coachRecommendation: CoachRecommendation {
        AICoachEngine.analyze(
            activities: activities,
            plannedWeeks: plannedWeeks,
            userSettings: activeSettings,
            now: Date()
        )
    }
    
    private func autoAdaptPlanIfNeeded() {
        guard activeSettings.isAutoAdaptationEnabled else { return }
        let rec = coachRecommendation
        if rec.isAdjustmentRecommended {
            AICoachEngine.applyAdaptation(
                recommendation: rec,
                in: modelContext,
                plannedWeeks: plannedWeeks,
                now: Date()
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if activeSettings.raceDate == nil {
                    ContentUnavailableView(
                        "Нет целевого старта",
                        systemImage: "calendar.badge.clock",
                        description: Text("Укажи дату целевого соревнования в настройках профиля")
                    )
                } else if plannedWeeks.isEmpty {
                    emptyPlannerForm
                } else {
                    plannerDashboardView
                }
            }
            .navigationTitle("План подготовки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
                
                if !plannedWeeks.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            // Re-trigger plan generation flow
                            withAnimation {
                                try? modelContext.delete(model: TrainingWeek.self)
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            .onAppear {
                if let raceD = activeSettings.raceDate {
                    targetRaceDate = raceD
                }
                let isMetric = activeSettings.isMetric
                let divisor = isMetric ? 1000.0 : 1609.344
                currentRunningVolumeKm = activeSettings.targetWeeklyDistanceMeters > 0 ? (activeSettings.targetWeeklyDistanceMeters / divisor) : (isMetric ? 40.0 : 25.0)
                currentCyclingHours = activeSettings.weeklyCyclingGoalHours > 0 ? activeSettings.weeklyCyclingGoalHours : 3.0
                
                autoAdaptPlanIfNeeded()
            }
        }
    }
    
    // MARK: - Generation Form View
    
    private var emptyPlannerForm: some View {
        Form {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue.gradient)
                        .padding(.top)
                    
                    Text("Создайте план тренировок")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    
                    Text("Укажите ваши цели и дату старта. Мы автоматически сгенерируем адаптивный график нагрузки 3:1 с тейпером к вашей главной гонке.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            
            Section("Целевой старт") {
                DatePicker("Дата соревнований", selection: $targetRaceDate, displayedComponents: .date)
            }
            
            Section("Текущая базовая нагрузка") {
                VStack(alignment: .leading, spacing: 8) {
                    let isMetric = activeSettings.isMetric
                    Text(isMetric ? "Беговой объём в неделю: \(Int(currentRunningVolumeKm)) км" : "Беговой объём в неделю: \(Int(currentRunningVolumeKm)) миль")
                        .font(.headline)
                    Slider(value: $currentRunningVolumeKm, in: (isMetric ? 10...150 : 5...100), step: 5)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Велосипедные часы в неделю: \(Int(currentCyclingHours)) ч")
                        .font(.headline)
                    Slider(value: $currentCyclingHours, in: 0...20, step: 0.5)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                Button {
                    generatePlan()
                } label: {
                    Text("Сгенерировать план")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.blue)
            }
        }
    }
    
    // MARK: - Planner Dashboard View
    
    private var plannerDashboardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // AI Coach section at the top of the dashboard
                aiCoachSection
                    .padding(.top, 10)
                
                // 1. Horizontal Scroll Weeks
                Text("Календарь подготовки")
                    .font(.title3.weight(.bold))
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(plannedWeeks) { week in
                                weekCard(week)
                                    .id(week.id)
                                    .onTapGesture {
                                        withAnimation {
                                            selectedWeekId = week.id
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onAppear {
                        // Select current week automatically if possible
                        if selectedWeekId == nil {
                            selectedWeekId = plannedWeeks.first?.id
                        }
                    }
                }
                
                // 2. Details of selected week
                if let selectedId = selectedWeekId, let week = plannedWeeks.first(where: { $0.id == selectedId }) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(week.typeString)
                                .font(.headline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(weekTypeColor(week.typeString).opacity(0.15))
                                .foregroundStyle(weekTypeColor(week.typeString))
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            Text(weekDateRangeString(week.startDate))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                        
                        // Volume completed / goal targets
                        let stats = weekStats(for: week)
                        
                        VStack(spacing: 12) {
                            if week.targetVolumeMeters > 0 {
                                let isMetric = activeSettings.isMetric
                                let divisor = isMetric ? 1000.0 : 1609.344
                                volumeProgressBar(
                                    title: isMetric ? "Беговые километры" : "Беговые мили",
                                    completed: stats.runMeters / divisor,
                                    target: week.targetVolumeMeters / divisor,
                                    unit: isMetric ? "км" : "миль",
                                    color: .blue
                                )
                            }
                            
                            if week.targetCyclingHours > 0 {
                                volumeProgressBar(
                                    title: "Велосипедное время",
                                    completed: stats.bikeDuration / 3600.0,
                                    target: week.targetCyclingHours,
                                    unit: "ч",
                                    color: .green
                                )
                            }
                        }
                        
                        Divider()
                        
                        Text("Методические рекомендации по дням:")
                            .font(.headline)
                            .padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(coachingGuidelines(for: week.typeString), id: \.day) { item in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(item.day)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(item.day == "Вс" || item.day == "Сб" ? Color.orange : Color.secondary)
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(item.desc)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Week Card Sub-component
    
    private func weekCard(_ week: TrainingWeek) -> some View {
        let isSelected = week.id == selectedWeekId
        let stats = weekStats(for: week)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(weekDateLabel(week.startDate))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text(week.typeString)
                .font(.headline)
                .foregroundStyle(weekTypeColor(week.typeString))
                .lineLimit(1)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                if week.targetVolumeMeters > 0 {
                    let isMetric = activeSettings.isMetric
                    let divisor = isMetric ? 1000.0 : 1609.344
                    Text(String(format: isMetric ? "Бег: %.0f/%.0f км" : "Бег: %.0f/%.0f миль", stats.runMeters / divisor, week.targetVolumeMeters / divisor))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if week.targetCyclingHours > 0 {
                    Text(String(format: "Вело: %.1f/%.1f ч", stats.bikeDuration / 3600.0, week.targetCyclingHours))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 160, height: 140, alignment: .leading)
        .background(isSelected ? Color.blue.opacity(0.12) : Color.gray.opacity(0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
    
    private func volumeProgressBar(
        title: String,
        completed: Double,
        target: Double,
        unit: String,
        color: Color
    ) -> some View {
        let pct = target > 0 ? min(1.0, completed / target) : 0.0
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f / %.1f %@", completed, target, unit))
                    .font(.caption.weight(.bold))
            }
            
            GeometryReader { geom in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.gradient)
                        .frame(width: geom.size.width * CGFloat(pct))
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Sports Science Calculators & Helpers
    
    private struct WeekVolumeStats {
        let runMeters: Double
        let bikeDuration: TimeInterval
    }
    
    private func weekStats(for week: TrainingWeek) -> WeekVolumeStats {
        let start = week.startDate
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        
        let weekActs = activities.filter { $0.startDate >= start && $0.startDate < end }
        
        let runM = weekActs
            .filter { $0.sportType.lowercased().contains("run") }
            .reduce(0.0) { $0 + $1.distanceMeters }
        
        let bikeTime = weekActs
            .filter { $0.sportType.lowercased().contains("ride") || $0.sportType.lowercased().contains("cycl") }
            .reduce(0.0) { $0 + $1.movingTime }
            
        return WeekVolumeStats(runMeters: runM, bikeDuration: bikeTime)
    }
    
    private func generatePlan() {
        Task {
            // Save settings values if specified
            activeSettings.raceDate = targetRaceDate
            let multiplier = activeSettings.isMetric ? 1000.0 : 1609.344
            activeSettings.targetWeeklyDistanceMeters = currentRunningVolumeKm * multiplier
            activeSettings.weeklyCyclingGoalHours = currentCyclingHours
            
            TrainingPlanner.generatePlan(
                raceDate: targetRaceDate,
                currentRunningVolumeMeters: currentRunningVolumeKm * multiplier,
                currentCyclingHours: currentCyclingHours,
                in: modelContext
            )
        }
    }
    
    private func weekTypeColor(_ type: String) -> Color {
        let cleanType = type.replacingOccurrences(of: " (Адапт.)", with: "")
                            .replacingOccurrences(of: " (Adapted)", with: "")
        switch cleanType {
        case "Базовая": return .blue
        case "Развивающая": return .purple
        case "Ударная": return .red
        case "Восстановительная": return .green
        case "Подводящая", "Подводящая (тейпер)": return .orange
        default: return .secondary
        }
    }
    
    private func weekDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        return "Неделя \(formatter.string(from: date))"
    }
    
    private func weekDateRangeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM"
        let end = Calendar.current.date(byAdding: .day, value: 6, to: date) ?? date
        return "\(formatter.string(from: date)) — \(formatter.string(from: end))"
    }
    
    private struct GuidelineItem {
        let day: String
        let title: String
        let desc: String
    }
    
    private func coachingGuidelines(for type: String) -> [GuidelineItem] {
        switch type {
        case "Базовая":
            return [
                GuidelineItem(day: "Пн", title: "Отдых", desc: "Полное восстановление нервной системы. Растяжка."),
                GuidelineItem(day: "Вт", title: "Аэробный кросс", desc: "Лёгкий бег в Z2 продолжительностью 40-50 минут."),
                GuidelineItem(day: "Ср", title: "Кросс-тренинг", desc: "Плавание, силовая тренировка на кор или лёгкая езда 45 минут."),
                GuidelineItem(day: "Чт", title: "Бег + ускорения", desc: "Лёгкий аэробный бег 40 мин + 6 ускорений по 15 секунд в горку."),
                GuidelineItem(day: "Пт", title: "Отдых", desc: "День релаксации, баня или массаж."),
                GuidelineItem(day: "Сб", title: "Поддерживающий кросс", desc: "Лёгкая пробежка 45 минут. Хорошее самочувствие."),
                GuidelineItem(day: "Вс", title: "Длительный кросс", desc: "Спокойный объёмный бег в Z2. Контроль дыхания (45% недельного объёма).")
            ]
        case "Развивающая":
            return [
                GuidelineItem(day: "Пн", title: "Отдых", desc: "День подготовки к развивающему блоку нагрузки."),
                GuidelineItem(day: "Вт", title: "Интервальная сессия", desc: "Разминка + 5-6 повторений по 1 км в темпе Z4. Восстановление 3 мин."),
                GuidelineItem(day: "Ср", title: "Восстановительный бег", desc: "Мягкая пробежка в Z1 продолжительностью 35-45 минут."),
                GuidelineItem(day: "Чт", title: "Темповая тренировка", desc: "Разминка + 20-30 минут непрерывного бега на уровне темпа Z3."),
                GuidelineItem(day: "Пт", title: "Отдых", desc: "Полный физический покой. Магниевая ванна."),
                GuidelineItem(day: "Сб", title: "Аэробный бег", desc: "Мягкий кросс 50 минут для утилизации лактата."),
                GuidelineItem(day: "Вс", title: "Длительный прогрессивный бег", desc: "Начните в Z2, последние 15 минут перейдите в целевой темп марафона.")
            ]
        case "Ударная":
            return [
                GuidelineItem(day: "Пн", title: "Отдых", desc: "Важнейший восстановительный день перед пиковой неделей."),
                GuidelineItem(day: "Вт", title: "Жёсткие интервалы", desc: "Разминка + 10 повторений по 400 метров в Z5. Отдых 200 метров трусцой."),
                GuidelineItem(day: "Ср", title: "Восстановление", desc: "Активная регенерация. Плавание 45 мин или кросс 40 мин в Z1."),
                GuidelineItem(day: "Чт", title: "Пороговый бег", desc: "Разминка + 3 повторения по 10 минут на уровне LTHR. Отдых 3 минуты."),
                GuidelineItem(day: "Пт", title: "Лёгкая разминка", desc: "Короткая пробежка 30 минут + ОФП."),
                GuidelineItem(day: "Сб", title: "Темповый кросс", desc: "Стабильный бег 60-70 минут в Z2-Z3. Моделирование питания."),
                GuidelineItem(day: "Вс", title: "Максимальный длительный кросс", desc: "Максимальный объём подготовки. Медленный темп, Z2, 90-120 минут.")
            ]
        case "Восстановительная":
            return [
                GuidelineItem(day: "Пн", title: "Полный отдых", desc: "Абсолютный покой. Организм адаптируется к перенесённой нагрузке."),
                GuidelineItem(day: "Вт", title: "Лёгкая регенерация", desc: "Очень медленный восстановительный бег в Z1 — 30-40 минут."),
                GuidelineItem(day: "Ср", title: "Стретчинг / Йога", desc: "Растяжка всех мышечных групп, мобилизация суставов."),
                GuidelineItem(day: "Чт", title: "Короткий аэробный кросс", desc: "Лёгкий бег в Z2 — 35 минут. Лёгкость в ногах."),
                GuidelineItem(day: "Пт", title: "Полный отдых", desc: "Зарядка аккумулятора суперкомпенсации."),
                GuidelineItem(day: "Сб", title: "Короткий кросс", desc: "Лёгкая восстановительная пробежка 30 минут."),
                GuidelineItem(day: "Вс", title: "Мягкий полу-длительный бег", desc: "Спокойная пробежка 50 минут. Пульс строго до 130 ударов/мин.")
            ]
        case "Подводящая", "Подводящая (тейпер)":
            return [
                GuidelineItem(day: "Пн", title: "Отдых", desc: "Начало предстартовой недели. Мышцы восстанавливают гликоген."),
                GuidelineItem(day: "Вт", title: "Разминочные интервалы", desc: "Разминка + 3x1 км в темпе целевого старта. Почувствовать скорость."),
                GuidelineItem(day: "Ср", title: "Лёгкая пробежка", desc: "Абсолютно спокойный кросс 30 минут для удержания тонуса."),
                GuidelineItem(day: "Чт", title: "Отдых и растяжка", desc: "Массажный валик. Увеличение доли углеводов в питании."),
                GuidelineItem(day: "Пт", title: "Предстартовая подводка", desc: "20 минут лёгкого бега + 3 лёгких ускорения. Тонус мышц."),
                GuidelineItem(day: "Сб", title: "Полный отдых", desc: "Подготовка экипировки, отдых ног, углеводное насыщение."),
                GuidelineItem(day: "Вс", title: "ДЕНЬ СТАРТА!", desc: "Ваша главная цель. Получите удовольствие от результатов подготовки!")
            ]
        default:
            return []
        }
    }
    
    // MARK: - AI Coach Assistant UI Section
    
    private var aiCoachSection: some View {
        let rec = coachRecommendation
        let isMetric = activeSettings.isMetric
        
        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(.purple.gradient)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isMetric ? "ИИ-Ассистент Тренера" : "AI Coach Assistant")
                        .font(.headline)
                    Text("CTL: \(Int(round(rec.ctl))) | ATL: \(Int(round(rec.atl)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Status Capsule
                Text(statusLabel(rec.status, isMetric: isMetric))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(rec.status).opacity(0.15))
                    .foregroundStyle(statusColor(rec.status))
                    .cornerRadius(6)
            }
            
            Divider()
            
            // Insight message
            Text(isMetric ? rec.insightRU : rec.insightEN)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // Compliance section if previous week exists
            if rec.runCompliance != nil || rec.bikeCompliance != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isMetric ? "Выполнение плана за прошлую неделю:" : "Previous week plan compliance:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    if let rc = rec.runCompliance, let targetRun = rec.targetRunMeters, let actualRun = rec.actualRunMeters {
                        let divisor = isMetric ? 1000.0 : 1609.344
                        let targetVal = targetRun / divisor
                        let actualVal = actualRun / divisor
                        let unit = isMetric ? "км" : "миль"
                        HStack {
                            Text(isMetric ? "Бег:" : "Run:")
                                .font(.caption)
                                .frame(width: 45, alignment: .leading)
                            
                            ProgressView(value: min(1.0, rc))
                                .tint(.blue)
                            
                            Text(String(format: "%.0f%% (%.1f/%.1f %@", rc * 100, actualVal, targetVal, unit))
                                .font(.caption.weight(.bold))
                        }
                    }
                    
                    if let bc = rec.bikeCompliance, let targetBike = rec.targetBikeHours, let actualBike = rec.actualBikeHours {
                        HStack {
                            Text(isMetric ? "Вело:" : "Bike:")
                                .font(.caption)
                                .frame(width: 45, alignment: .leading)
                            
                            ProgressView(value: min(1.0, bc))
                                .tint(.green)
                            
                            Text(String(format: "%.0f%% (%.1f/%.1f ч)", bc * 100, actualBike, targetBike))
                                .font(.caption.weight(.bold))
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            Divider()
            
            // Actions
            HStack {
                Toggle(isOn: Binding(
                    get: { activeSettings.isAutoAdaptationEnabled },
                    set: { newValue in
                        activeSettings.isAutoAdaptationEnabled = newValue
                        try? modelContext.save()
                        if newValue {
                            autoAdaptPlanIfNeeded()
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isMetric ? "Авто-адаптация" : "Auto-Adaptation")
                            .font(.subheadline.weight(.semibold))
                        Text(isMetric ? "С подстройкой под усталость" : "Adjust targets based on fatigue")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.purple)
                
                if rec.isAdjustmentRecommended && !activeSettings.isAutoAdaptationEnabled {
                    Spacer()
                    
                    Button {
                        withAnimation {
                            AICoachEngine.applyAdaptation(
                                recommendation: rec,
                                in: modelContext,
                                plannedWeeks: plannedWeeks,
                                now: Date()
                            )
                        }
                    } label: {
                        Text(isMetric ? "Адаптировать" : "Adapt Plan")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.purple.gradient)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func statusColor(_ status: TrainerStatus) -> Color {
        switch status {
        case .optimal: return .green
        case .overload: return .red
        case .recovery: return .orange
        case .underload: return .purple
        case .fresh: return .blue
        }
    }
    
    private func statusLabel(_ status: TrainerStatus, isMetric: Bool) -> String {
        switch status {
        case .optimal: return isMetric ? "ОПТИМАЛЬНО" : "OPTIMAL"
        case .overload: return isMetric ? "ПЕРЕГРУЗКА" : "OVERLOAD"
        case .recovery: return isMetric ? "ВОССТАНОВЛЕНИЕ" : "RECOVERY"
        case .underload: return isMetric ? "НЕДОГРУЗКА" : "UNDERLOAD"
        case .fresh: return isMetric ? "СВЕЖЕСТЬ" : "FRESH"
        }
    }
}
