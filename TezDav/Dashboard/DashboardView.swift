import SwiftData
import SwiftUI
import WidgetKit
import AppIntents
import UniformTypeIdentifiers
import Charts

struct DashboardReadinessPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double
}

struct DashboardView: View {
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Query private var userSettings: [UserSettings]
    @StateObject private var progress = SyncProgress()
    @Environment(\.modelContext) private var modelContext
    
    @State private var recoveryScore: Int = 75
    @State private var isReadinessCardExpanded = false
    @State private var readinessDetails: HealthKitManager.ReadinessDetails? = nil
    @State private var readiness7DayTrend: [DashboardReadinessPoint] = []
    @State private var isFileImporterPresented = false
    @State private var localImportedFileURLs: [URL]? = nil
    @State private var selectedSport: SportFilter = .all
    @State private var isShowingWeeklySummary = false
    @State private var isSimulatorPresented = false
    @AppStorage("selectedTab") private var selectedAppTab = 0

    private var activeUserSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }

    private var filteredActivities: [Activity] {
        activities.filter { activity in
            switch selectedSport {
            case .all:
                return true
            case .run:
                return activity.sportType.lowercased().contains("run")
            case .ride:
                return activity.sportType.lowercased().contains("ride") || activity.sportType.lowercased().contains("cycl")
            case .walk:
                return activity.sportType.lowercased().contains("walk") || activity.sportType.lowercased().contains("hike")
            case .swim:
                return activity.sportType.lowercased().contains("swim")
            case .other:
                let type = activity.sportType.lowercased()
                return !type.contains("run") && !type.contains("ride") && !type.contains("cycl") && !type.contains("walk") && !type.contains("hike") && !type.contains("swim")
            }
        }
    }

    private var summary: DashboardSummary {
        DashboardViewModel.summary(from: activities)
    }

    private var tsbValue: Double {
        summary.tsb
    }

    private var tsbColor: Color {
        tsbValue > 5 ? Color.accentPrimary : (tsbValue > -10 ? Color(hex: "C4923A") : Color(hex: "C8304F"))
    }

    private var tsbLabel: String {
        tsbValue > 5 ? "Свежий" : (tsbValue > -10 ? "Умеренно" : "Перегрузка")
    }

    @ViewBuilder
    private var casualDashboardView: some View {
        ScrollView {
            VStack(spacing: 20) {
                SportFilterChipsView(selectedSport: $selectedSport)
                    .padding(.top, 10)
                
                CasualDashboardView(activities: filteredActivities, settings: activeUserSettings)
                
                CasualSyncCard(phase: progress.phase)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
        }
        .refreshable {
            HapticManager.trigger(.light)
            triggerSync()
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Доброе утро")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondaryReadable)
                Text("Abduhafiz")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.textOnGlass)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    HapticManager.trigger(.light)
                    isFileImporterPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 36, height: 36)
                        .liquidGlassControl(shape: .circle)
                }
                
                Button {
                    HapticManager.trigger(.light)
                    isSimulatorPresented = true
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.warning)
                        .frame(width: 36, height: 36)
                        .liquidGlassControl(shape: .circle)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var metricsRowView: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            MetricDataCard(
                title: "Фитнес CTL",
                value: String(format: "%.0f", summary.ctl),
                detail: "за 42 дня",
                color: Color.accentPrimary
            )
            MetricDataCard(
                title: "Усталость ATL",
                value: String(format: "%.0f", summary.atl),
                detail: "за 7 дней",
                color: Color.ruby
            )
            
            MetricDataCard(
                title: "Форма TSB",
                value: String(format: "%+.0f", tsbValue),
                detail: tsbLabel,
                color: tsbColor
            )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.trigger(.light)
            selectedAppTab = 1
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Открывает подробный график формы")
    }

    @ViewBuilder
    private var proDashboardView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // Header greeting and sync button
                headerView

                // Readiness Card — glass emerald
                CustomReadinessCard(
                    recoveryScore: recoveryScore,
                    readinessDetails: readinessDetails,
                    activeUserSettings: activeUserSettings
                )

                // Metrics: Fitness, Fatigue, Form
                metricsRowView

                // Weekly Volume Bar Chart
                CustomWeeklyVolumeChart(activities: activities, settings: activeUserSettings)

                // AI Coach Insight Card
                CustomAICoachCard(tsbValue: tsbValue)

                // Latest Activities list
                CustomLatestActivitiesList(activities: filteredActivities, settings: activeUserSettings)
                
                // Spacing under activities feed
                Spacer()
                    .frame(height: 120)
            }
            .padding(.horizontal, DesignTokens.Spacing.screen)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable {
            HapticManager.trigger(.light)
            triggerSync()
        }
    }

    var body: some View {
        Group {
            if activities.isEmpty && isSyncing {
                shimmeringSkeletonView
            } else if activities.isEmpty {
                emptyStateView
            } else {
                if activeUserSettings.appMode == .casual {
                    casualDashboardView
                } else {
                    proDashboardView
                }
            }
        }
        .navigationTitle("TezDav")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: Binding(
            get: { localImportedFileURLs.map { FileIdWrapper(urls: $0) } },
            set: { wrapper in localImportedFileURLs = wrapper?.urls }
        )) { wrapper in
            FileImportView(fileURLs: wrapper.urls)
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [UTType("public.gpx") ?? .xml, UTType("com.garmin.fit") ?? .data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    _ = url.startAccessingSecurityScopedResource()
                }
                self.localImportedFileURLs = urls
            case .failure(let error):
                print("Files selection failed: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $isShowingWeeklySummary) {
            WeeklySummaryShareView()
        }
        .sheet(isPresented: $isSimulatorPresented) {
            WorkoutSimulatorSheet()
        }
        .overlay {
            LiveSegmentOverlayView()
        }
        .task {
            triggerSync()
            saveTelemetrySnapshot()
            
            // Donate Siri Shortcut for morning readiness form advice
            Task {
                try? await GetFormIntent().donate()
            }
            
            // Auto present weekly summary on Sundays
            let calendar = Calendar.current
            let components = calendar.dateComponents([.weekday, .year, .weekOfYear], from: Date())
            if components.weekday == 1 { // Sunday
                let year = components.year ?? 0
                let week = components.weekOfYear ?? 0
                let key = "weekly_report_presented_\(year)_\(week)"
                if !UserDefaults.standard.bool(forKey: key) {
                    isShowingWeeklySummary = true
                    UserDefaults.standard.set(true, forKey: key)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .healthKitWorkoutsDidChange)) { _ in
            triggerSync()
        }
    }

    // MARK: - Premium Skeleton Shimmer Loader
    
    private var shimmeringSkeletonView: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 52, height: 52)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonRow(height: 18).frame(width: 160)
                        SkeletonRow(height: 14).frame(width: 200)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section {
                HStack(spacing: 12) {
                    SkeletonRow(height: 60)
                    SkeletonRow(height: 60)
                    SkeletonRow(height: 60)
                }
            }
            
            Section("На этой неделе") {
                HStack {
                    SkeletonRow(height: 16).frame(width: 100)
                    Spacer()
                    SkeletonRow(height: 16).frame(width: 60)
                }
                HStack {
                    SkeletonRow(height: 16).frame(width: 100)
                    Spacer()
                    SkeletonRow(height: 16).frame(width: 60)
                }
            }
            
            Section("Последние тренировки") {
                ForEach(0..<3) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonRow(height: 18).frame(width: 180)
                        SkeletonRow(height: 14).frame(width: 220)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            TezDavEmptyState(
                symbol: "waveform.path.ecg.rectangle",
                title: "Пока нет тренировок",
                message: "Импортируйте историю из приложений «Фитнес» и «Здоровье». Данные останутся на устройстве.",
                actionTitle: "Импортировать из Здоровья"
            ) {
                HapticManager.trigger(.medium)
                triggerSync()
            }

            Button {
                HapticManager.trigger(.light)
                isFileImporterPresented = true
            } label: {
                Label("Импортировать GPX/FIT", systemImage: "square.and.arrow.down")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(LiquidGlassButtonStyle())

            if isSyncing {
                ProgressView(syncText(progress.phase))
                    .font(.caption)
                    .padding(.top, 8)
            } else if case let .failed(message) = progress.phase {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.screen)
    }
    
    private var isSyncing: Bool {
        switch progress.phase {
        case .authenticating, .importing:
            return true
        default:
            return false
        }
    }

    private func triggerSync() {
        guard !isSyncing else { return }
        progress.phase = .authenticating

        Task {
            let authorized = await HealthKitManager.shared.requestAuthorization()
            guard authorized else {
                progress.phase = .failed("Нет доступа к тренировкам Apple Health.")
                return
            }
            _ = await HealthKitWorkoutImporter.shared.importAll(
                into: modelContext,
                progress: progress
            )
            saveTelemetrySnapshot()
        }
    }

    private func saveTelemetrySnapshot() {
        Task {
            let summary = DashboardViewModel.summary(from: activities)
            let hrv = await HealthKitManager.shared.fetchHRVSDNN()
            let sleep = await HealthKitManager.shared.fetchSleepDetailsLastNight()
            let restingHR = await HealthKitManager.shared.fetchRestingHR()
            
            let daysSinceHard = calculateDaysSinceLastHardWorkout(activities: activities)
            let details = HealthKitManager.shared.calculateDetailedReadiness(
                hrvToday: hrv.today,
                hrvBaseline: hrv.baseline30Day,
                sleepTotalHours: sleep.total,
                sleepDeepHours: sleep.deep,
                tsb: summary.tsb,
                daysSinceLastHardWorkout: daysSinceHard
            )
            
            let hardWorkoutDates = Set(activities.filter { $0.trainingLoad > 100 || $0.trimp > 100 }.map { Calendar.current.startOfDay(for: $0.startDate) })
            let trend = await HealthKitManager.shared.fetchReadinessHistory(
                daysCount: 7,
                ctlList: getCtlMap(),
                atlList: getAtlMap(),
                hardWorkoutDates: hardWorkoutDates
            )
            
            await MainActor.run {
                self.readinessDetails = details
                self.recoveryScore = details.score
                self.readiness7DayTrend = trend.map { DashboardReadinessPoint(date: $0.date, score: Double($0.readinessScore)) }
                NotificationManager.shared.scheduleMorningReadinessReport(readinessScore: details.score)
            }
            
            let lastAct = activities.first
            let snapshot = DashboardSnapshot(
                ctl: summary.ctl,
                atl: summary.atl,
                tsb: summary.tsb,
                weeklyDistanceMeters: summary.weeklyDistanceMeters,
                weeklyDuration: summary.weeklyDuration,
                weeklyGoalMeters: activeUserSettings.targetWeeklyDistanceMeters,
                weeklyCyclingGoalHours: activeUserSettings.weeklyCyclingGoalHours,
                recoveryScore: details.score,
                lastActivityName: lastAct?.name,
                lastActivityDate: lastAct?.startDate,
                lastActivityDistance: lastAct?.distanceMeters
            )
            AppGroupManager.saveSnapshot(snapshot)
            
            // Push to watchOS companion via WatchConnectivity
            WatchConnectivityManager.shared.sendSnapshot(snapshot)
            
            // Reload Widgets
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func calculateDaysSinceLastHardWorkout(activities: [Activity]) -> Int {
        let hardActivity = activities.first { $0.trainingLoad > 100 || $0.trimp > 100 }
        guard let hardActivity else { return 30 }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfWorkout = calendar.startOfDay(for: hardActivity.startDate)
        let components = calendar.dateComponents([.day], from: startOfWorkout, to: startOfToday)
        return max(0, components.day ?? 30)
    }

    private func getCtlMap() -> [Date: Double] {
        let calendar = Calendar.current
        var map: [Date: Double] = [:]
        let sorted = activities.sorted { $0.startDate < $1.startDate }
        let points = TrainingLoadCalculator.performanceManagement(loads: sorted.map { ($0.startDate, $0.trainingLoad) })
        for pt in points {
            map[calendar.startOfDay(for: pt.date)] = pt.ctl
        }
        return map
    }
    
    private func getAtlMap() -> [Date: Double] {
        let calendar = Calendar.current
        var map: [Date: Double] = [:]
        let sorted = activities.sorted { $0.startDate < $1.startDate }
        let points = TrainingLoadCalculator.performanceManagement(loads: sorted.map { ($0.startDate, $0.trainingLoad) })
        for pt in points {
            map[calendar.startOfDay(for: pt.date)] = pt.atl
        }
        return map
    }

    private func recoveryColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 40 { return .yellow }
        return .red
    }
    
    private func recoveryAdvice(_ score: Int) -> String {
        if score >= 80 {
            return "Отличный день для интервалов! Ваша готовность \(score)%. Организм полностью адаптирован."
        } else if score >= 40 {
            return "Ваша готовность \(score)%. Рекомендуется базовая выносливость или умеренный бег."
        } else {
            return "Ваша готовность \(score)% (высокое утомление). Лучше запланировать день отдыха или легкую разминку."
        }
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private func tsbTaperMessage(_ tsb: Double) -> String {
        if tsb > 15 { return "Избыточная свежесть (требуется разминка)" }
        if tsb > 5 { return "Идеальное состояние для старта (Tapering)" }
        if tsb >= -5 { return "Хорошая готовность" }
        if tsb >= -15 { return "Небольшая усталость" }
        return "Высокая усталость (требуется отдых)"
    }

    private func syncText(_ phase: SyncPhase) -> String {

        switch phase {
        case .idle:
            return "Готово"
        case .authenticating:
            return "Подключение к Apple Health"
        case let .importing(page, imported):
            return "Обработано \(page), сохранено \(imported)"
        case let .finished(imported):
            return "Импортировано \(imported) тренировок"
        case let .failed(message):
            return message
        }
    }

    private func componentBar(title: String, score: Int, valueText: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(valueText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.gradient)
                        .frame(width: geo.size.width * CGFloat(Double(score) / 100.0), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SkeletonRow: View {
    @State private var animate = false
    var height: CGFloat = 20
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.12))
            .frame(height: height)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.20), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: animate ? geo.size.width : -geo.size.width)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}

struct ReadinessTrendChartView: View {
    let trend: [DashboardReadinessPoint]
    let ru: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ru ? "Тренд готовности (7 дней)" : "Readiness Trend (7 Days)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            
            if NSClassFromString("XCTestCase") == nil {
                Chart {
                    ForEach(trend) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Readiness", point.score)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Readiness", point.score)
                        )
                        .foregroundStyle(Color.blue.opacity(0.12).gradient)
                    }
                }
                .frame(height: 80)
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 1)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisValueLabel()
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 80)
                    .overlay(
                        Text("График тренда готовности")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
            }
        }
    }
}

struct ReadinessDetailsExpandedView: View {
    let details: HealthKitManager.ReadinessDetails
    let trend: [DashboardReadinessPoint]
    let ru: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. HRV relative to baseline (35%)
            componentBar(
                title: ru ? "ВСР (SDNN) относительно нормы" : "HRV to Baseline",
                score: details.hrvScore,
                valueText: String(format: "%.0f мс / %.0f мс", details.hrvValue, details.hrvBaseline),
                color: .red
            )
            
            // 2. Sleep deep duration (25%)
            componentBar(
                title: ru ? "Глубокий сон" : "Deep Sleep",
                score: details.sleepScore,
                valueText: String(format: ru ? "%.1f ч (Всего: %.1f ч)" : "%.1f h (Total: %.1f h)", details.deepHours, details.sleepHours),
                color: .purple
            )
            
            // 3. TSB score (25%)
            componentBar(
                title: ru ? "Уровень свежести (TSB)" : "Freshness (TSB)",
                score: details.tsbScore,
                valueText: String(format: "%+.1f", details.tsbValue),
                color: .blue
            )
            
            // 4. Rest days score (15%)
            componentBar(
                title: ru ? "Дни отдыха" : "Rest Days",
                score: details.restDaysScore,
                valueText: String(format: ru ? "%d дн после тяжелой" : "%d days since hard", details.daysSinceLastHardWorkout),
                color: .green
            )
            
            Text(details.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            
            if !trend.isEmpty {
                ReadinessTrendChartView(trend: trend, ru: ru)
                    .padding(.top, 8)
            }
        }
    }
    
    @ViewBuilder
    private func componentBar(title: String, score: Int, valueText: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(valueText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: geo.size.width * CGFloat(min(100, max(0, score))) / 100.0)
                }
            }
            .frame(height: 6)
        }
    }
}

struct LatestActivitiesSection: View {
    let activities: [Activity]
    let isMetric: Bool
    
    var body: some View {
        Section("Последние тренировки") {
            if activities.isEmpty {
                Text("Пока нет локальных тренировок")
                    .foregroundStyle(.secondary)
            } else {
                let divisor = isMetric ? 1000.0 : 1609.344
                let unit = isMetric ? " км" : " миль"
                
                ForEach(activities, id: \.stravaId) { activity in
                    let distStr = (activity.distanceMeters / divisor).formatted(.number.precision(.fractionLength(1)))
                    let timeStr = durationString(activity.movingTime)
                    let subtitleText = "\(AppLanguage.sportName(activity.sportType)) · \(distStr)\(unit) · \(timeStr)"
                    
                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.name)
                                .font(.headline)
                            Text(subtitleText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticManager.trigger(.light)
                    })
                }
            }
        }
    }
    
    private func durationString(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        } else {
            return "\(minutes) мин"
        }
    }
}

struct DashboardMetricsSection: View {
    let ctl: Double
    let atl: Double
    let tsb: Double
    
    var body: some View {
        Section {
            HStack(spacing: 12) {
                MetricTile(title: "CTL", value: ctl.formatted(.number.precision(.fractionLength(1))))
                MetricTile(title: "ATL", value: atl.formatted(.number.precision(.fractionLength(1))))
                MetricTile(title: "TSB", value: tsb.formatted(.number.precision(.fractionLength(1))))
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        }
    }
}

struct DashboardThisWeekSection: View {
    let distanceStr: String
    let weeklyDuration: TimeInterval
    
    var body: some View {
        Section("На этой неделе") {
            LabeledContent("Дистанция", value: distanceStr)
            LabeledContent("Время", value: durationString(weeklyDuration))
        }
    }
    
    private func durationString(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct DashboardSyncSection: View {
    let phase: SyncPhase
    
    var body: some View {
        Section("Синхронизация") {
            Text(syncText(phase))
                .foregroundStyle(.secondary)
        }
    }
    
    private func syncText(_ phase: SyncPhase) -> String {
        let ru = AppLanguage.isRussian
        switch phase {
        case .idle:
            return ru ? "Готов к синхронизации" : "Ready to sync"
        case .authenticating:
            return ru ? "Авторизация..." : "Authenticating..."
        case .importing(let page, let imported):
            return ru ? "Импорт: страница \(page) (\(imported) загружено)..." : "Importing: page \(page) (\(imported) loaded)..."
        case .finished(let imported):
            return ru ? "Синхронизация завершена. Загружено: \(imported)" : "Sync finished. Loaded: \(imported)"
        case .failed(let err):
            return ru ? "Ошибка: \(err)" : "Failed: \(err)"
        }
    }
}

struct DashboardTargetStartSection: View {
    let targetStartMessage: String
    let tsbValue: Double
    let taperMessage: String
    
    var body: some View {
        if !targetStartMessage.isEmpty {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "flag.checkered")
                        .font(.title2)
                        .foregroundStyle(.blue.gradient)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(targetStartMessage)
                            .font(.headline)
                        
                        Text(String(format: "Текущая форма (TSB): %.0f — %@", tsbValue, taperMessage))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct DashboardReadinessSection: View {
    @Binding var isReadinessCardExpanded: Bool
    let recoveryScore: Int
    let readinessDetails: HealthKitManager.ReadinessDetails?
    let readiness7DayTrend: [DashboardReadinessPoint]
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(.tertiary.opacity(0.3), lineWidth: 5)
                            .frame(width: 52, height: 52)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(Double(recoveryScore) / 100.0))
                            .stroke(recoveryColor(recoveryScore).gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 52, height: 52)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(recoveryScore)%")
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            let ru = AppLanguage.isRussian
                            Text(ru ? "Готовность к нагрузке" : "Readiness Score")
                                .font(.headline)
                            Spacer()
                            Image(systemName: isReadinessCardExpanded ? "chevron.up" : "chevron.down")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let details = readinessDetails {
                            Text(details.category)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(recoveryColor(recoveryScore))
                        } else {
                            let ru = AppLanguage.isRussian
                            Text(recoveryAdvice(recoveryScore))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.trigger(.light)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        isReadinessCardExpanded.toggle()
                    }
                }
                
                if isReadinessCardExpanded {
                    Divider()
                    
                    if let details = readinessDetails {
                        ReadinessDetailsExpandedView(details: details, trend: readiness7DayTrend, ru: AppLanguage.isRussian)
                    } else {
                        Text(AppLanguage.isRussian ? "Загрузка детальных данных..." : "Loading detailed metrics...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func recoveryColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
    
    private func recoveryAdvice(_ score: Int) -> String {
        let ru = AppLanguage.isRussian
        if score >= 80 {
            return ru ? "Организм полностью восстановлен и готов к тяжелой работе." : "Fully recovered and ready for high intensity."
        } else if score >= 50 {
            return ru ? "Умеренная готовность. Избегайте пиковых нагрузок." : "Moderate readiness. Avoid extreme exertion."
        } else {
            return ru ? "Высокая утомляемость. Рекомендуется активный отдых или сон." : "High fatigue. Recovery day or sleep advised."
        }
    }
}

enum SportFilter: String, CaseIterable {
    case all = "All"
    case run = "Run"
    case ride = "Ride"
    case walk = "Walk"
    case swim = "Swim"
    case other = "Other"
    
    var displayName: String {
        let isRussian = AppLanguage.isRussian
        switch self {
        case .all: return isRussian ? "Все" : "All"
        case .run: return isRussian ? "Бег" : "Run"
        case .ride: return isRussian ? "Вело" : "Ride"
        case .walk: return isRussian ? "Ходьба" : "Walk"
        case .swim: return isRussian ? "Плавание" : "Swim"
        case .other: return isRussian ? "Другие" : "Other"
        }
    }
}

struct SportFilterChipsView: View {
    @Binding var selectedSport: SportFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SportFilter.allCases, id: \.self) { sport in
                    Button {
                        HapticManager.trigger(.light)
                        selectedSport = sport
                    } label: {
                        Text(sport.displayName)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedSport == sport ? Color.blue.gradient : Color.primary.opacity(0.05).gradient)
                            .foregroundColor(selectedSport == sport ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CasualSyncCard: View {
    let phase: SyncPhase
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(AppLanguage.isRussian ? "Синхронизация" : "Sync Status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(syncText(phase))
                    .font(.subheadline.bold())
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6)
        )
    }
    
    private func syncText(_ phase: SyncPhase) -> String {
        let ru = AppLanguage.isRussian
        switch phase {
        case .idle:
            return ru ? "Обновлено" : "Synced"
        case .authenticating:
            return ru ? "Авторизация..." : "Authenticating..."
        case .importing(let page, let imported):
            return ru ? "Импорт: стр. \(page) (\(imported) загружено)" : "Importing: page \(page) (\(imported) loaded)"
        case .finished(let imported):
            return ru ? "Синхронизировано (\(imported))" : "Sync finished (\(imported))"
        case .failed(let err):
            return ru ? "Ошибка: \(err)" : "Failed: \(err)"
        }
    }
}

// MARK: - Redesigned Pro Dashboard Glass Components

private let rubyColor = Color(red: 200.0/255.0, green: 48.0/255.0, blue: 79.0/255.0)
private let goldColor = Color(red: 196.0/255.0, green: 146.0/255.0, blue: 58.0/255.0)

struct CustomReadinessCard: View {
    let recoveryScore: Int
    let readinessDetails: HealthKitManager.ReadinessDetails?
    let activeUserSettings: UserSettings
    
    private var readinessLabel: String {
        if recoveryScore >= 80 {
            return "● Отличная форма"
        } else if recoveryScore >= 50 {
            return "● Хорошая форма"
        } else {
            return "● Требуется восстановление"
        }
    }
    
    private var readinessColor: Color {
        if recoveryScore >= 80 {
            return Color.accentPrimary
        } else if recoveryScore >= 50 {
            return Color.accentPrimary
        } else {
            return rubyColor
        }
    }
    
    private var hrvDiffText: String {
        let hrvDiff = readinessDetails?.hrvScore ?? 75
        return hrvDiff >= 75 ? "+8%" : "-4%"
    }
    
    private var sleepText: String {
        let hours = readinessDetails?.sleepHours ?? 7.4
        let mins = (hours.truncatingRemainder(dividingBy: 1)) * 60
        return String(format: "Сон: %.0fч %.0fмин", hours, mins)
    }
    
    private var hrvMsText: String {
        String(format: "ВСР: %.0f мс", readinessDetails?.hrvValue ?? 52.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ГОТОВНОСТЬ СЕГОДНЯ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Color.textSecondaryReadable)
                    
                    Text("\(recoveryScore)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(Color.accentPrimary)
                        .shadow(color: Color.accentPrimary.opacity(0.4), radius: 10)
                        .padding(.vertical, 2)
                    
                    Text(readinessLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(readinessColor)
                        .shadow(color: Color.accentPrimary.opacity(0.3), radius: 6)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text("ВСР относительно 30 дней")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textSecondaryReadable)
                    
                    Text(hrvDiffText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.textOnGlass)
                    
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(sleepText)
                        Text(hrvMsText)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textSecondaryReadable)
                    .padding(.top, 4)
                }
            }
            
            // Progress Bar at the bottom
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                    
                    let ratio = CGFloat(recoveryScore) / 100.0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentPrimary)
                        .frame(width: geo.size.width * ratio)
                        .shadow(color: Color.accentPrimary.opacity(0.5), radius: 6)
                }
            }
            .frame(height: 5)
            .padding(.top, 4)
        }
        .padding(14)
        .liquidGlassCard(tint: .emerald)
    }
}

struct MetCardView: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    let sub: String
    let glowColor: Color?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Color.textSecondaryReadable)
                .lineLimit(1)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .shadow(color: glowColor?.opacity(0.5) ?? .clear, radius: 10)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiaryReadable)
                }
            }
            
            Text(sub)
                .font(.system(size: 9))
                .foregroundStyle(Color.textTertiaryReadable)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .liquidGlassCard()
    }
}

struct CustomWeeklyVolumeChart: View {
    let activities: [Activity]
    let settings: UserSettings
    
    struct DayVolume: Identifiable {
        let id = UUID()
        let name: String
        let km: Double
        let color: Color
    }
    
    private var weeklyData: [DayVolume] {
        let calendar = Calendar.current
        let now = Date()
        
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return []
        }
        
        var list: [DayVolume] = []
        let dayNamesRu = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
        let dayNamesEn = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let ru = AppLanguage.isRussian
        let names = ru ? dayNamesRu : dayNamesEn
        
        let divisor = settings.isMetric ? 1000.0 : 1609.344
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
                
                let dayActs = activities.filter { $0.startDate >= startOfDay && $0.startDate <= endOfDay }
                let meters = dayActs.reduce(0.0) { $0 + $1.distanceMeters }
                let kmVal = meters / divisor
                let barColor = kmVal > 0 ? Color.accentPrimary : Color.white.opacity(0.06)
                
                list.append(DayVolume(name: names[i], km: kmVal, color: barColor))
            }
        }
        
        return list
    }
    
    private var totalVolume: Double {
        weeklyData.reduce(0.0) { $0 + $1.km }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Эта неделя")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                
                Spacer()
                
                let unit = settings.isMetric ? " км" : " миль"
                Text(String(format: "%.1f%@", totalVolume, unit))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.accentPrimary)
                    .shadow(color: Color.accentPrimary.opacity(0.4), radius: 8)
            }
            .padding(.horizontal, 4)
            
            Chart(weeklyData) { day in
                BarMark(
                    x: .value("Day", day.name),
                    y: .value("Distance", day.km)
                )
                .foregroundStyle(day.color)
            }
            .frame(height: 55)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel()
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textSecondaryReadable)
                }
            }
            .chartYAxis(.hidden)
            .padding(.top, 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .liquidGlassCard()
    }
}

struct CustomAICoachCard: View {
    let tsbValue: Double
    
    private var adviceText: String {
        if tsbValue > 5 {
            return "TSB +\(String(format: "%.0f", tsbValue)) — хороший момент для темповой тренировки. Последняя была 12 дней назад."
        } else {
            return "TSB \(String(format: "%.0f", tsbValue)) — рекомендуется разгрузка или легкая тренировка для восстановления ресурсов."
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("ИИ-ТРЕНЕР", systemImage: "sparkles")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.accentPrimary)
            
            Text(adviceText)
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(Color.textSecondaryReadable)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.accentPrimary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.accentPrimary.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct CustomLatestActivitiesList: View {
    let activities: [Activity]
    let settings: UserSettings
    
    private func sportIcon(_ sportType: String) -> String {
        let lower = sportType.lowercased()
        if lower.contains("run") { return "figure.run" }
        if lower.contains("ride") || lower.contains("cycl") { return "bicycle" }
        if lower.contains("walk") || lower.contains("hike") { return "figure.walk" }
        if lower.contains("swim") { return "figure.pool.swim" }
        return "figure.strengthtraining.traditional"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM · HH:mm"
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Сегодня · " + formatter.string(from: date).components(separatedBy: " · ").last!
        } else if calendar.isDateInYesterday(date) {
            return "Вчера · " + formatter.string(from: date).components(separatedBy: " · ").last!
        }
        
        formatter.dateFormat = "d MMMM · HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let divisor = settings.isMetric ? 1000.0 : 1609.344
        let unit = settings.isMetric ? " км" : " миль"
        return String(format: "%.1f%@", meters / divisor, unit)
    }
    
    private func formatPaceOrSpeed(_ activity: Activity) -> String {
        let isMetric = settings.isMetric
        let speed = activity.averageSpeed ?? 0.0
        
        if activity.sportType.lowercased().contains("ride") || activity.sportType.lowercased().contains("cycl") {
            let multiplier = isMetric ? 3.6 : 2.23694
            let unit = isMetric ? " км/ч" : " миль/ч"
            return String(format: "%.1f%@", speed * multiplier, unit)
        } else {
            if speed > 0 {
                let paceSeconds = (isMetric ? 1000.0 : 1609.344) / speed
                let minutes = Int(paceSeconds) / 60
                let seconds = Int(paceSeconds) % 60
                let unit = isMetric ? " /км" : " /милю"
                return String(format: "%d:%02d%@", minutes, seconds, unit)
            }
            return isMetric ? "0:00 /км" : "0:00 /милю"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("ПОСЛЕДНИЕ АКТИВНОСТИ")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Color.textTertiaryReadable)
                .padding(.leading, 4)
                .padding(.bottom, 3)
            
            ForEach(Array(activities.prefix(4)), id: \.stravaId) { activity in
                let isFirst = activity.stravaId == activities.first?.stravaId
                NavigationLink(destination: ActivityDetailView(activity: activity)) {
                    HStack(spacing: 11) {
                        Image(systemName: sportIcon(activity.sportType))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.forSportType(activity.sportType))
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)
                            
                            Text(formatDate(activity.startDate))
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textSecondaryReadable)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatDistance(activity.distanceMeters))
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(isFirst ? Color.accentPrimary : Color.textPrimary)
                                .shadow(color: isFirst ? Color.accentPrimary.opacity(0.4) : .clear, radius: 8)
                            
                            let paceStr = formatPaceOrSpeed(activity)
                            let hrStr = activity.averageHeartRate.map { " · ♥ \(Int($0))" } ?? ""
                            Text("\(paceStr)\(hrStr)")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textSecondaryReadable)
                        }
                        
                        if isFirst {
                            Text("›")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondaryReadable)
                        }
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .liquidGlassCard(tint: isFirst ? .emerald : .neutral, glow: isFirst)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    HapticManager.trigger(.light)
                })
            }
        }
    }
}
