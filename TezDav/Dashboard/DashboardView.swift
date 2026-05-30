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

    private let config = StravaConfig.fromBundle()
    private let tokenStore = KeychainTokenStore()

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

    var body: some View {
        Group {
            if activities.isEmpty && isSyncing {
                shimmeringSkeletonView
            } else if activities.isEmpty {
                emptyStateView
            } else {
                let summary = DashboardViewModel.summary(from: activities)
                let isMetric = activeUserSettings.isMetric
                let divisor = isMetric ? 1000.0 : 1609.344
                let unit = isMetric ? " km" : " mi"
                let distanceStr = (summary.weeklyDistanceMeters / divisor).formatted(.number.precision(.fractionLength(1))) + unit
                
                let daysLeft: Int? = {
                    if let raceDate = activeUserSettings.raceDate {
                        let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: raceDate)).day ?? 0
                        return diff >= 0 ? diff : nil
                    }
                    return nil
                }()
                let raceDistStr: String = {
                    if let dist = activeUserSettings.raceDistanceMeters {
                        let unitLabel = isMetric ? "км" : "миль"
                        return String(format: " (%.1f %@", dist / divisor, unitLabel) + ")"
                    }
                    return ""
                }()
                let targetStartMessage: String = {
                    guard let days = daysLeft else { return "" }
                    let suffix = days == 1 ? "день" : (days < 5 ? "дня" : "дней")
                    return "До целевого старта\(raceDistStr): \(days) \(suffix)!"
                }()
                
                if activeUserSettings.appMode == .casual {
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
                } else {
                    List {
                        Section {
                            SportFilterChipsView(selectedSport: $selectedSport)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                        
                        DashboardTargetStartSection(
                            targetStartMessage: targetStartMessage,
                            tsbValue: summary.tsb,
                            taperMessage: tsbTaperMessage(summary.tsb)
                        )

                        DashboardReadinessSection(
                            isReadinessCardExpanded: $isReadinessCardExpanded,
                            recoveryScore: recoveryScore,
                            readinessDetails: readinessDetails,
                            readiness7DayTrend: readiness7DayTrend
                        )

                        Section {
                            DailyRecommendationCardView(activities: activities, settings: activeUserSettings, context: modelContext)
                        }

                        DashboardMetricsSection(ctl: summary.ctl, atl: summary.atl, tsb: summary.tsb)

                        DashboardThisWeekSection(distanceStr: distanceStr, weeklyDuration: summary.weeklyDuration)

                        let filteredLatest = filteredActivities.prefix(5)
                        LatestActivitiesSection(activities: Array(filteredLatest), isMetric: activeUserSettings.isMetric)

                        DashboardSyncSection(phase: progress.phase)
                    }
                    .refreshable {
                        HapticManager.trigger(.light)
                        triggerSync()
                    }
                }
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    HapticManager.trigger(.light)
                    isFileImporterPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    triggerSync()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isSyncing)
            }
        }
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
            
            Section("This Week") {
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
            
            Section("Latest Activities") {
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
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue.gradient)
                
                Text("Подключи Strava или импортируй GPX/FIT файл чтобы начать")
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Все ваши спортивные данные будут храниться конфиденциально и обрабатываться локально на вашем устройстве.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            VStack(spacing: 16) {
                Button {
                    HapticManager.trigger(.medium)
                    isFileImporterPresented = true
                } label: {
                    Label("Импортировать GPX или FIT", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue.gradient)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button {
                    HapticManager.trigger(.medium)
                    connectStrava()
                } label: {
                    Label("Подключить аккаунт Strava", systemImage: "link")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange.gradient)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private func connectStrava() {
        do {
            let state = UUID().uuidString
            let authURL = try StravaOAuth.authorizationURL(config: config, state: state)
            UIApplication.shared.open(authURL)
        } catch {
            print("Failed to open Strava auth: \(error)")
        }
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
        
        let refresher = StravaTokenRefresher(config: config)
        let session = StravaSession(tokenStore: tokenStore, refresher: refresher)
        let apiClient = StravaAPIClient(session: session)
        let syncService = SyncService(apiClient: apiClient, modelContext: modelContext, progress: progress)
        
        Task {
            let latestActivityDate = activities.map { $0.startDate }.max()
            await syncService.importAll(after: latestActivityDate)
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
            return "Ready"
        case .authenticating:
            return "Connecting Strava"
        case let .importing(page, imported):
            return "Importing page \(page), \(imported) activities saved"
        case let .finished(imported):
            return "Imported \(imported) activities"
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
                title: ru ? "HRV (SDNN) к базовому" : "HRV to Baseline",
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
        Section("Latest Activities") {
            if activities.isEmpty {
                Text("No local activities yet")
                    .foregroundStyle(.secondary)
            } else {
                let divisor = isMetric ? 1000.0 : 1609.344
                let unit = isMetric ? " km" : " mi"
                
                ForEach(activities, id: \.stravaId) { activity in
                    let distStr = (activity.distanceMeters / divisor).formatted(.number.precision(.fractionLength(1)))
                    let timeStr = durationString(activity.movingTime)
                    let subtitleText = "\(activity.sportType) · \(distStr)\(unit) · \(timeStr)"
                    
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
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
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
        Section("This Week") {
            LabeledContent("Distance", value: distanceStr)
            LabeledContent("Time", value: durationString(weeklyDuration))
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
        Section("Sync") {
            Text(syncText(phase))
                .foregroundStyle(.secondary)
        }
    }
    
    private func syncText(_ phase: SyncPhase) -> String {
        let ru = Locale.current.identifier.hasPrefix("ru")
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
                            let ru = Locale.current.identifier.hasPrefix("ru")
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
                            let ru = Locale.current.identifier.hasPrefix("ru")
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
                        ReadinessDetailsExpandedView(details: details, trend: readiness7DayTrend, ru: Locale.current.identifier.hasPrefix("ru"))
                    } else {
                        Text(Locale.current.identifier.hasPrefix("ru") ? "Загрузка детальных данных..." : "Loading detailed metrics...")
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
        let ru = Locale.current.identifier.hasPrefix("ru")
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
        let isRussian = Locale.current.identifier.hasPrefix("ru")
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
                Text(Locale.current.identifier.hasPrefix("ru") ? "Синхронизация" : "Sync Status")
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
        let ru = Locale.current.identifier.hasPrefix("ru")
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


