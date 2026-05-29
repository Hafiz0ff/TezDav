import SwiftData
import SwiftUI
import WidgetKit
import UniformTypeIdentifiers

struct DashboardView: View {
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Query private var userSettings: [UserSettings]
    @StateObject private var progress = SyncProgress()
    @Environment(\.modelContext) private var modelContext
    
    @State private var recoveryScore: Int = 7
    @State private var isFileImporterPresented = false
    @State private var localImportedFileURLs: [URL]? = nil

    private let config = StravaConfig.fromBundle()
    private let tokenStore = KeychainTokenStore()

    private var activeUserSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }

    var body: some View {
        Group {
            if activities.isEmpty && isSyncing {
                shimmeringSkeletonView
            } else if activities.isEmpty {
                emptyStateView
            } else {
                let summary = DashboardViewModel.summary(from: activities)
                
                List {
                    if let raceDate = activeUserSettings.raceDate {
                        let daysLeft = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: raceDate)).day ?? 0
                        if daysLeft >= 0 {
                            Section {
                                HStack(spacing: 12) {
                                    Image(systemName: "flag.checkered")
                                        .font(.title2)
                                        .foregroundStyle(.blue.gradient)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        let isMetric = activeUserSettings.isMetric
                                        let divisor = isMetric ? 1000.0 : 1609.344
                                        let unitLabel = isMetric ? "км" : "миль"
                                        let raceDistStr = activeUserSettings.raceDistanceMeters != nil ? String(format: " (%.1f %@", activeUserSettings.raceDistanceMeters! / divisor, unitLabel) + ")" : ""
                                        Text("До целевого старта\(raceDistStr): \(daysLeft) \(daysLeft == 1 ? "день" : (daysLeft < 5 ? "дня" : "дней"))!")
                                            .font(.headline)
                                        
                                        let tsbValue = summary.tsb
                                        Text(String(format: "Текущая форма (TSB): %.0f — %@", tsbValue, tsbTaperMessage(tsbValue)))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // Recovery Score Card
                    Section {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(.tertiary.opacity(0.3), lineWidth: 5)
                                    .frame(width: 52, height: 52)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(Double(recoveryScore) / 10.0))
                                    .stroke(recoveryColor(recoveryScore).gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                    .frame(width: 52, height: 52)
                                    .rotationEffect(.degrees(-90))
                                
                                Text("\(recoveryScore)")
                                    .font(.title2.weight(.bold))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Индекс восстановления: \(recoveryScore)/10")
                                    .font(.headline)
                                Text(recoveryAdvice(recoveryScore))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section {
                        HStack(spacing: 12) {
                            MetricTile(title: "CTL", value: summary.ctl.formatted(.number.precision(.fractionLength(1))))
                            MetricTile(title: "ATL", value: summary.atl.formatted(.number.precision(.fractionLength(1))))
                            MetricTile(title: "TSB", value: summary.tsb.formatted(.number.precision(.fractionLength(1))))
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }

                    Section("This Week") {
                        let isMetric = activeUserSettings.isMetric
                        let divisor = isMetric ? 1000.0 : 1609.344
                        let unit = isMetric ? " km" : " mi"
                        LabeledContent("Distance", value: (summary.weeklyDistanceMeters / divisor).formatted(.number.precision(.fractionLength(1))) + unit)
                        LabeledContent("Time", value: durationString(summary.weeklyDuration))
                    }

                    Section("Latest Activities") {
                        if summary.latestActivities.isEmpty {
                            Text("No local activities yet")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(summary.latestActivities) { activity in
                                NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(activity.name)
                                            .font(.headline)
                                        let isMetric = activeUserSettings.isMetric
                                        let divisor = isMetric ? 1000.0 : 1609.344
                                        let unit = isMetric ? " km" : " mi"
                                        Text("\(activity.sportType) · \((activity.distanceMeters / divisor).formatted(.number.precision(.fractionLength(1))))\(unit) · \(durationString(activity.movingTime))")
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

                    Section("Sync") {
                        Text(syncText(progress.phase))
                            .foregroundStyle(.secondary)
                    }
                }
                .refreshable {
                    HapticManager.trigger(.light)
                    triggerSync()
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
        .task {
            triggerSync()
            saveTelemetrySnapshot()
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
            let recovery = HealthKitManager.shared.calculateRecoveryScore(
                hrvToday: hrv.today,
                hrvBaseline: hrv.baseline30Day,
                tsb: summary.tsb
            )
            
            await MainActor.run {
                self.recoveryScore = recovery
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
                recoveryScore: recovery,
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

    private func recoveryColor(_ score: Int) -> Color {
        if score >= 8 { return .green }
        if score >= 5 { return .yellow }
        return .red
    }
    
    private func recoveryAdvice(_ score: Int) -> String {
        if score >= 8 {
            return "Отличная готовность. Подходящий день для темповой или силовой сессии!"
        } else if score >= 5 {
            return "Умеренная готовность. Хороший день для легких аэробных тренировок."
        } else {
            return "Высокий уровень утомления. Рекомендуется полный отдых или легкое восстановление."
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
