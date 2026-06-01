import SwiftData
import SwiftUI
import CoreLocation
import PhotosUI

struct ProfileView: View {
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Query private var settingsList: [UserSettings]
    @Query(sort: \TrainingWeek.startDate, order: .forward) private var plannedWeeksList: [TrainingWeek]
    @Query private var allSegmentsList: [IntervalSegment]
    @Query private var gearsList: [GearItem]
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var progress = SyncProgress()
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    // UI Form states
    @State private var maxHeartRate: String = ""
    @State private var restingHeartRate: String = ""
    @State private var weightKg: String = ""
    @State private var mainSport: String = "Run"
    @State private var birthDate = Date()
    @State private var hasBirthDate = false
    
    @State private var isHeartRateZonesAutomatic = true
    @State private var hrZone1Max: String = ""
    @State private var hrZone2Max: String = ""
    @State private var hrZone3Max: String = ""
    @State private var hrZone4Max: String = ""
    
    @State private var lthrPaceMinutes: Int = 4
    @State private var lthrPaceSeconds: Int = 30
    @State private var runningFTP: String = ""
    @State private var cyclingFTP: String = ""
    @State private var bikeWeightKg: String = ""
    
    @State private var weeklyRunningGoalKm: String = ""
    @State private var weeklyCyclingGoalHours: String = ""
    
    @State private var raceDate = Date()
    @State private var hasRaceDate = false
    @State private var raceDistanceKm: String = ""
    
    @State private var showDeleteConfirmation = false
    @State private var isMetric = true
    @State private var notificationStatusGranted = false
    
    @State private var appMode: AppMode = .pro
    @State private var targetWeeklyActiveMinutes: String = "150"
    
    @State private var isHealthKitEnabled = false
    @State private var stepsToday: Double = 0
    @State private var activeCaloriesToday: Double = 0
    
    @State private var exportStartDate = Date().addingTimeInterval(-86400 * 30)
    @State private var exportEndDate = Date()
    @State private var profileShareURL: URL? = nil
    @State private var isShowingProfileShareSheet = false
    
    private let config = StravaConfig.fromBundle()
    private let tokenStore = KeychainTokenStore()
    
    var activeSettings: UserSettings {
        settingsList.first ?? UserSettings()
    }
    
    var hasCyclingHistory: Bool {
        activities.contains { $0.sportType.lowercased().contains("ride") }
    }
    
    var lastSyncDate: String {
        let descriptor = FetchDescriptor<SyncState>()
        if let syncState = try? modelContext.fetch(descriptor).first, let date = syncState.lastSuccessfulSync {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return "Никогда"
    }

    var body: some View {
        Form {
                // Section 1: Personal Profile Info
                Section {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                if let data = activeSettings.avatarData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.blue.gradient)
                                }
                                
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.accentPrimary)
                                    .background(Color.black.clipShape(Circle()))
                                    .offset(x: 2, y: 2)
                            }
                        }
                        .onChange(of: selectedPhotoItem) { _, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    activeSettings.avatarData = data
                                    try? modelContext.save()
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activeSettings.stravaAccountName ?? "Атлет TezDav")
                                .font(.headline)
                            Text("Подключено к Strava")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Streaks indicators
                        VStack(alignment: .trailing, spacing: 4) {
                            if dailyStreak > 0 {
                                HStack(spacing: 4) {
                                    Text("🔥")
                                    Text("\(dailyStreak) дн")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.orange)
                                }
                            }
                            if weeklyStreak > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                    Text("\(weeklyStreak) нед")
                                        .font(.caption.bold())
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Toggle("Указать дату рождения", isOn: $hasBirthDate)
                    
                    if hasBirthDate {
                        DatePicker("Дата рождения", selection: $birthDate, displayedComponents: .date)
                    }
                    
                    Picker("Система измерения", selection: $isMetric) {
                        Text("Метрическая (км, кг)").tag(true)
                        Text("Имперская (мили, фунты)").tag(false)
                    }
                    .onChange(of: isMetric) { oldValue, newValue in
                        if oldValue != newValue {
                            if let w = Double(weightKg) {
                                let converted = newValue ? (w / 2.20462) : (w * 2.20462)
                                weightKg = String(format: "%.1f", converted)
                            }
                            if !bikeWeightKg.isEmpty, let b = Double(bikeWeightKg) {
                                let converted = newValue ? (b / 2.20462) : (b * 2.20462)
                                bikeWeightKg = String(format: "%.1f", converted)
                            }
                            if !weeklyRunningGoalKm.isEmpty, let g = Double(weeklyRunningGoalKm) {
                                let converted = newValue ? (g * 1.609344) : (g / 1.609344)
                                weeklyRunningGoalKm = String(format: "%.0f", converted)
                            }
                            if !raceDistanceKm.isEmpty, let r = Double(raceDistanceKm) {
                                let converted = newValue ? (r * 1.609344) : (r / 1.609344)
                                raceDistanceKm = String(format: "%.1f", converted)
                            }
                        }
                    }
                    
                    Picker("Режим приложения", selection: $appMode) {
                        Text("Любитель (Casual)").tag(AppMode.casual)
                        Text("Спортсмен (Pro)").tag(AppMode.pro)
                    }
                    
                    if appMode == .casual {
                        HStack {
                            Text("Цель активных минут")
                            Spacer()
                            TextField("150", text: $targetWeeklyActiveMinutes)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                    
                    HStack {
                        Text(isMetric ? "Вес (кг)" : "Вес (фунты)")
                        Spacer()
                        TextField(isMetric ? "70.0" : "154.3", text: $weightKg)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    Picker("Основной вид спорта", selection: $mainSport) {
                        Text("Бег").tag("Run")
                        Text("Велосипед").tag("Ride")
                        Text("Триатлон").tag("Triathlon")
                        Text("Ходьба").tag("Walk")
                        Text("Плавание").tag("Swim")
                    }
                }
                
                // Section 2: Heart Rate Zones
                Section {
                    Toggle("Расчет пульсовых зон авто (Friel)", isOn: $isHeartRateZonesAutomatic)
                    
                    HStack {
                        Text("Максимальный пульс")
                        Spacer()
                        TextField(String(format: "%.0f", hasBirthDate ? estimatedMaxHR : 190.0), text: $maxHeartRate)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Пульс покоя")
                        Spacer()
                        TextField("60", text: $restingHeartRate)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    if !isHeartRateZonesAutomatic {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Индивидуальные границы зон (макс. BPM)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                            
                            HStack {
                                Text("Зона 1 макс (Восстановление)")
                                Spacer()
                                TextField("120", text: $hrZone1Max)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                            }
                            
                            HStack {
                                Text("Зона 2 макс (Выносливость)")
                                Spacer()
                                TextField("140", text: $hrZone2Max)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                            }
                            
                            HStack {
                                Text("Зона 3 макс (Темп)")
                                Spacer()
                                TextField("160", text: $hrZone3Max)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                            }
                            
                            HStack {
                                Text("Зона 4 макс (Порог)")
                                Spacer()
                                TextField("180", text: $hrZone4Max)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                            }
                        }
                    }
                } header: {
                    Text("Пульсовые зоны")
                } footer: {
                    autoHRZonesFooterView()
                }
                
                // Section 3: Running Thresholds
                Section("Беговые пороги") {
                    HStack {
                        Text("Темп LTHR")
                        Spacer()
                        HStack(spacing: 4) {
                            Menu {
                                Picker("Минуты", selection: $lthrPaceMinutes) {
                                    ForEach(2..<12) { min in
                                        Text("\(min) мин").tag(min)
                                    }
                                }
                            } label: {
                                Text("\(lthrPaceMinutes)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.accentPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                            }
                            
                            Text(":")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Menu {
                                Picker("Секунды", selection: $lthrPaceSeconds) {
                                    ForEach(0..<60) { sec in
                                        Text(String(format: "%02d сек", sec)).tag(sec)
                                    }
                                }
                            } label: {
                                Text(String(format: "%02d", lthrPaceSeconds))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.accentPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                            }
                            
                            Text("/км")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Беговой FTP (Вт)")
                        Spacer()
                        TextField("250", text: $runningFTP)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                // Section 4: Cycling Thresholds (Only shown if cycling history exists)
                if hasCyclingHistory {
                    Section("Велосипедные пороги") {
                        HStack {
                            Text("Велосипедный FTP (Вт)")
                            Spacer()
                            TextField("250", text: $cyclingFTP)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        
                        HStack {
                            Text(isMetric ? "Вес велосипеда (кг, опционально)" : "Вес велосипеда (фунты, опционально)")
                            Spacer()
                            TextField(isMetric ? "8.5" : "18.7", text: $bikeWeightKg)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }
                
                // Section 5: Goals & Races
                Section("Тренировочные цели") {
                    HStack {
                        Text(isMetric ? "Целевой недельный объём (км)" : "Целевой недельный объём (миль)")
                        Spacer()
                        TextField(isMetric ? "50" : "30", text: $weeklyRunningGoalKm)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Целевые недельные часы (вело)")
                        Spacer()
                        TextField("5.0", text: $weeklyCyclingGoalHours)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    Toggle("Целевое соревнование", isOn: $hasRaceDate)
                    
                    if hasRaceDate {
                        DatePicker("Дата старта", selection: $raceDate, displayedComponents: .date)
                        
                        HStack {
                            Text(isMetric ? "Дистанция старта (км)" : "Дистанция старта (миль)")
                            Spacer()
                            TextField(isMetric ? "42.2" : "26.2", text: $raceDistanceKm)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }
                // Section: Gear & Equipment
                Section(Locale.current.identifier.hasPrefix("ru") ? "Снаряжение & Экипировка" : "Gear & Equipment") {
                    NavigationLink(destination: GearListView()) {
                        HStack {
                            Label(Locale.current.identifier.hasPrefix("ru") ? "Управление экипировкой" : "Manage Equipment", systemImage: "shoeprints.fill")
                            
                            Spacer()
                            
                            let redGears = gearsList.filter { $0.isActive && ($0.maxDistanceKm > 0 && ($0.currentDistanceKm / $0.maxDistanceKm) >= 0.85) }
                            if !redGears.isEmpty {
                                Text("\(redGears.count)")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red, in: Capsule())
                            }
                        }
                    }
                }
                
                // Section: Gamification & Achievements
                Section(Locale.current.identifier.hasPrefix("ru") ? "Достижения & Награды" : "Gamification & Achievements") {
                    NavigationLink(destination: AchievementsShowcaseView()) {
                        Label(
                            Locale.current.identifier.hasPrefix("ru") ? "Мои награды и значки" : "My Badges & Rewards",
                            systemImage: "trophy.fill"
                        )
                    }
                }
                
                // Section: Activity Heatmap
                Section(Locale.current.identifier.hasPrefix("ru") ? "Карта активности" : "Activity Heatmap") {
                    ContributionsHeatmapView(activities: activities)
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }
                
                // Section: Personal Geography
                Section(Locale.current.identifier.hasPrefix("ru") ? "Личная география" : "Personal Geography") {
                    personalGeographySection
                }
                
                // Section: Apple Health & Telemetry
                Section("Синхронизация Apple Health") {
                    Toggle("Интеграция с Apple Health", isOn: $isHealthKitEnabled)
                        .onChange(of: isHealthKitEnabled) { oldValue, newValue in
                            if newValue {
                                Task {
                                    let success = await HealthKitManager.shared.requestAuthorization()
                                    isHealthKitEnabled = success
                                    if success {
                                        await loadHealthTelemetry()
                                    }
                                }
                            }
                        }
                    
                    if isHealthKitEnabled {
                        HStack {
                            Text("Шаги за сегодня")
                            Spacer()
                            Text(String(format: "%.0f", stepsToday))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Активные калории")
                            Spacer()
                            Text(String(format: "%.0f ккал", activeCaloriesToday))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Section: iCloud Synchronization
                Section(Locale.current.identifier.hasPrefix("ru") ? "Синхронизация iCloud" : "iCloud Synchronization") {
                    HStack {
                        Label(Locale.current.identifier.hasPrefix("ru") ? "Статус iCloud" : "iCloud Status", systemImage: "cloud.fill")
                            .foregroundColor(.blue)
                        Spacer()
                        Text(Locale.current.identifier.hasPrefix("ru") ? "Синхронизировано" : "Synced")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(Locale.current.identifier.hasPrefix("ru") ? "Контейнер CloudKit" : "CloudKit Container")
                        Spacer()
                        Text("iCloud.com.hafizov.tezdav")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(Locale.current.identifier.hasPrefix("ru") ? "Последнее обновление" : "Last Synced")
                        Spacer()
                        Text(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        try? modelContext.save()
                    }) {
                        Text(Locale.current.identifier.hasPrefix("ru") ? "Синхронизировать сейчас" : "Force Sync Now")
                            .foregroundColor(.blue)
                    }
                }
                
                // Section: Export Data
                Section("Экспорт данных") {
                    DatePicker("С даты", selection: $exportStartDate, displayedComponents: .date)
                    DatePicker("По дату", selection: $exportEndDate, displayedComponents: .date)
                    
                    Button {
                        triggerCSVHistoryExport()
                    } label: {
                        Label("Экспорт истории в CSV", systemImage: "tablecells")
                    }
                    
                    Button {
                        triggerJSONBackupExport()
                    } label: {
                        Label("Полный бэкап в JSON", systemImage: "archivebox")
                    }
                }
                
                // Section 6: Strava Sync & Reconnection
                Section("Синхронизация с Strava") {
                    HStack {
                        Text("Последний импорт")
                        Spacer()
                        Text(lastSyncDate)
                            .foregroundStyle(.secondary)
                    }
                    
                    if isSyncing {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text(syncText(progress.phase))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            triggerSync()
                        } label: {
                            Label("Синхронизировать сейчас", systemImage: "arrow.clockwise")
                        }
                        
                        Button {
                            reconnectStrava()
                        } label: {
                            Label("Переподключить Strava", systemImage: "link")
                        }
                    }
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Сбросить все данные", systemImage: "trash")
                    }
                }
                
                // Demo Data Section (for screenshots / testing)
                Section {
                    Button {
                        DemoDataSeeder.seedAllDemoData(modelContext: modelContext)
                        HapticManager.success()
                    } label: {
                        Label("Загрузить демо-данные", systemImage: "wand.and.stars")
                            .foregroundStyle(Color.accentPrimary)
                    }
                } header: {
                    Text("Демонстрация")
                } footer: {
                    Text("Заполняет все экраны реалистичными демо-данными. Текущие данные будут заменены.")
                        .font(.caption)
                }
            }
            .padding(.top, -45)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveSettings()
                        HapticManager.success()
                    } label: {
                        Image(systemName: "floppydisk")
                            .renderingMode(.original)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.accentPrimary)
                            .padding(8)
                            .background(Color.accentPrimary.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.accentPrimary.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $isShowingProfileShareSheet) {
                if let url = profileShareURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .onAppear {
                loadSettingsIntoUI()
                requestNotificationsOnFirstEntry()
                checkHealthKitStatus()
            }
            .alert("Удалить все данные?", isPresented: $showDeleteConfirmation) {
                Button("Отмена", role: .cancel) {}
                Button("Сбросить всё", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("Это действие безвозвратно удалит все синхронизированные активности, маршруты, рекорды и настройки из локального хранилища.")
            }
        }
    
    // MARK: - State Helpers
    
    private struct HRZoneDisplay: Identifiable {
        let id: String
        let name: String
        let label: String
        let range: String
        let color: Color
    }
    
    private func calculateAutoHRZones() -> [HRZoneDisplay] {
        let effMax = maxHRDouble > 0 ? maxHRDouble : estimatedMaxHR
        let z1Limit = Int(effMax * 0.65)
        let z2Limit = Int(effMax * 0.75)
        let z3Limit = Int(effMax * 0.85)
        let z4Limit = Int(effMax * 0.92)
        
        return [
            HRZoneDisplay(id: "Z1", name: "Z1", label: "Восстановление", range: "< \(z1Limit)", color: .blue),
            HRZoneDisplay(id: "Z2", name: "Z2", label: "Выносливость", range: "\(z1Limit)-\(z2Limit)", color: .green),
            HRZoneDisplay(id: "Z3", name: "Z3", label: "Темп", range: "\(z2Limit)-\(z3Limit)", color: .yellow),
            HRZoneDisplay(id: "Z4", name: "Z4", label: "Порог", range: "\(z3Limit)-\(z4Limit)", color: .orange),
            HRZoneDisplay(id: "Z5", name: "Z5", label: "Анаэробный", range: "> \(z4Limit)", color: .red)
        ]
    }
    
    @ViewBuilder
    private func autoHRZonesFooterView() -> some View {
        if isHeartRateZonesAutomatic {
            VStack(alignment: .leading, spacing: 6) {
                Text("Авто-зоны пульса:")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                let zones = calculateAutoHRZones()
                
                ForEach(zones) { zone in
                    HStack {
                        Circle()
                            .fill(zone.color)
                            .frame(width: 8, height: 8)
                        Text(zone.name)
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                            .frame(width: 24, alignment: .leading)
                        Text(zone.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(zone.range) BPM")
                            .font(.caption.monospacedDigit().bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        } else {
            Text("Зона 5 будет рассчитана как пульс выше границы Зоны 4.")
        }
    }
    
    private var estimatedMaxHR: Double {
        if hasBirthDate {
            let ageComponents = Calendar.current.dateComponents([.year], from: birthDate, to: .now)
            if let age = ageComponents.year {
                return Double(220 - age)
            }
        }
        return 190.0
    }
    
    private var maxHRDouble: Double {
        Double(maxHeartRate) ?? 0.0
    }
    
    private var isSyncing: Bool {
        switch progress.phase {
        case .authenticating, .importing:
            return true
        default:
            return false
        }
    }
    
    // MARK: - UI Actions
    
    private func loadSettingsIntoUI() {
        let settings: UserSettings
        if let first = settingsList.first {
            settings = first
        } else {
            let newSettings = UserSettings()
            modelContext.insert(newSettings)
            try? modelContext.save()
            settings = newSettings
        }
        
        isMetric = settings.isMetric
        maxHeartRate = settings.maxHeartRate > 0 ? String(format: "%.0f", settings.maxHeartRate) : ""
        restingHeartRate = settings.restingHeartRate > 0 ? String(format: "%.0f", settings.restingHeartRate) : ""
        
        let displayWeight = settings.isMetric ? settings.weightKg : (settings.weightKg * 2.20462)
        weightKg = String(format: "%.1f", displayWeight)
        mainSport = settings.mainSport
        
        if let birth = settings.birthDate {
            birthDate = birth
            hasBirthDate = true
        } else {
            hasBirthDate = false
        }
        
        isHeartRateZonesAutomatic = settings.isHeartRateZonesAutomatic
        hrZone1Max = settings.hrZone1Max > 0 ? String(format: "%.0f", settings.hrZone1Max) : ""
        hrZone2Max = settings.hrZone2Max > 0 ? String(format: "%.0f", settings.hrZone2Max) : ""
        hrZone3Max = settings.hrZone3Max > 0 ? String(format: "%.0f", settings.hrZone3Max) : ""
        hrZone4Max = settings.hrZone4Max > 0 ? String(format: "%.0f", settings.hrZone4Max) : ""
        
        let totalSeconds = Int(settings.lthrPaceSecondsPerKm)
        lthrPaceMinutes = max(2, totalSeconds / 60)
        lthrPaceSeconds = totalSeconds % 60
        
        runningFTP = settings.runningFTP > 0 ? String(format: "%.0f", settings.runningFTP) : ""
        cyclingFTP = settings.cyclingFTP > 0 ? String(format: "%.0f", settings.cyclingFTP) : ""
        
        if let bikeW = settings.bikeWeightKg {
            let displayBikeWeight = settings.isMetric ? bikeW : (bikeW * 2.20462)
            bikeWeightKg = String(format: "%.1f", displayBikeWeight)
        } else {
            bikeWeightKg = ""
        }
        
        let displayGoal = settings.isMetric ? (settings.targetWeeklyDistanceMeters / 1000) : (settings.targetWeeklyDistanceMeters / 1609.344)
        weeklyRunningGoalKm = settings.targetWeeklyDistanceMeters > 0 ? String(format: "%.0f", displayGoal) : ""
        weeklyCyclingGoalHours = settings.weeklyCyclingGoalHours > 0 ? String(format: "%.1f", settings.weeklyCyclingGoalHours) : ""
        
        if let raceD = settings.raceDate {
            raceDate = raceD
            hasRaceDate = true
        } else {
            hasRaceDate = false
        }
        
        if let raceDist = settings.raceDistanceMeters {
            let displayRaceDist = settings.isMetric ? (raceDist / 1000.0) : (raceDist / 1609.344)
            raceDistanceKm = String(format: "%.1f", displayRaceDist)
        } else {
            raceDistanceKm = ""
        }
        
        appMode = settings.appMode
        targetWeeklyActiveMinutes = String(format: "%.0f", settings.targetWeeklyActiveMinutes)
    }
    
    private func checkHealthKitStatus() {
        Task {
            let authorized = await HealthKitManager.shared.isAuthorized()
            await MainActor.run {
                self.isHealthKitEnabled = authorized
            }
            if authorized {
                await loadHealthTelemetry()
            }
        }
    }
    
    private func loadHealthTelemetry() async {
        let (steps, calories) = await HealthKitManager.shared.fetchDailyTelemetry()
        await MainActor.run {
            self.stepsToday = steps
            self.activeCaloriesToday = calories
        }
    }
    
    private func saveSettings() {
        let settings = activeSettings
        
        settings.isMetric = isMetric
        settings.maxHeartRate = Double(maxHeartRate) ?? 0.0
        settings.restingHeartRate = Double(restingHeartRate) ?? 60.0
        
        let rawWeight = Double(weightKg) ?? 70.0
        settings.weightKg = isMetric ? rawWeight : (rawWeight / 2.20462)
        settings.mainSport = mainSport
        
        settings.birthDate = hasBirthDate ? birthDate : nil
        
        settings.isHeartRateZonesAutomatic = isHeartRateZonesAutomatic
        if !isHeartRateZonesAutomatic {
            settings.hrZone1Max = Double(hrZone1Max) ?? 120.0
            settings.hrZone2Max = Double(hrZone2Max) ?? 140.0
            settings.hrZone3Max = Double(hrZone3Max) ?? 160.0
            settings.hrZone4Max = Double(hrZone4Max) ?? 180.0
        }
        
        let lthrSeconds = Double(lthrPaceMinutes * 60 + lthrPaceSeconds)
        settings.lthrPaceSecondsPerKm = lthrSeconds
        settings.runningThresholdPaceSecondsPerKm = lthrSeconds // keep backward compatibility
        
        settings.runningFTP = Double(runningFTP) ?? 250.0
        settings.cyclingFTP = Double(cyclingFTP) ?? 250.0
        
        if let rawBike = Double(bikeWeightKg) {
            settings.bikeWeightKg = isMetric ? rawBike : (rawBike / 2.20462)
        } else {
            settings.bikeWeightKg = nil
        }
        
        settings.appMode = appMode
        settings.targetWeeklyActiveMinutes = Double(targetWeeklyActiveMinutes) ?? 150.0
        
        let rawGoal = Double(weeklyRunningGoalKm) ?? 0.0
        settings.targetWeeklyDistanceMeters = isMetric ? (rawGoal * 1000.0) : (rawGoal * 1609.344)
        settings.weeklyCyclingGoalHours = Double(weeklyCyclingGoalHours) ?? 5.0
        
        settings.raceDate = hasRaceDate ? raceDate : nil
        if hasRaceDate, let rawRaceD = Double(raceDistanceKm) {
            settings.raceDistanceMeters = isMetric ? (rawRaceD * 1000.0) : (rawRaceD * 1609.344)
        } else {
            settings.raceDistanceMeters = nil
        }
        
        try? modelContext.save()
        
        // 1. Recalculate historical training load metrics instantly
        Task {
            await TrainingLoadCalculator.recalculateAllActivities(context: modelContext, settings: settings)
            
            // 2. Reschedule notification triggers reflecting the new settings
            NotificationManager.shared.rescheduleAllTriggers(settings: settings, context: modelContext)
        }
    }
    
    private func requestNotificationsOnFirstEntry() {
        Task {
            let alreadyGranted = await NotificationManager.shared.isPermissionGranted()
            if !alreadyGranted {
                _ = await NotificationManager.shared.requestPermission()
            }
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
            
            // Fetch and cache the profile details from Strava in the background
            if let athleteInfo = try? await apiClient.athlete() {
                let name = "\(athleteInfo.firstname ?? "") \(athleteInfo.lastname ?? "")".trimmingCharacters(in: .whitespaces)
                activeSettings.stravaAccountName = name.isEmpty ? "Strava Атлет" : name
                activeSettings.lastSyncedAt = .now
            }
            
            await syncService.importAll(after: latestActivityDate)
            
            // Trigger check and notifications for new records after sync closes
            let newSynced = activities.filter { $0.importedAt > Date().addingTimeInterval(-60) }
            NotificationManager.shared.checkAndNotifyNewRecords(activitiesSynced: newSynced, context: modelContext)
            
            // Re-evaluate current TSB state for warnings
            if let currentPmc = DashboardViewModel.summary(from: activities).tsb as Double? {
                NotificationManager.shared.checkTSBOverload(tsb: currentPmc, settings: activeSettings, context: modelContext)
            }
            
            // Update weekly schedules
            NotificationManager.shared.rescheduleAllTriggers(settings: activeSettings, context: modelContext)
        }
    }
    
    private func reconnectStrava() {
        do {
            let state = UUID().uuidString
            let authURL = try StravaOAuth.authorizationURL(config: config, state: state)
            UIApplication.shared.open(authURL)
        } catch {
            print("Failed to reconnect Strava: \(error)")
        }
    }
    
    private func resetAllData() {
        // Delete all persistence
        try? modelContext.delete(model: Activity.self)
        try? modelContext.delete(model: ActivityStreamSample.self)
        try? modelContext.delete(model: SyncState.self)
        try? modelContext.delete(model: UserSettings.self)
        
        try? modelContext.save()
        
        // Remove all pending alerts
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        loadSettingsIntoUI()
    }
    
    private func syncText(_ phase: SyncPhase) -> String {
        switch phase {
        case .idle:
            return "Готово"
        case .authenticating:
            return "Подключение к Strava..."
        case let .importing(page, imported):
            return "Импорт страницы \(page), \(imported) тренировок сохранено"
        case let .finished(imported):
            return "Успешно импортировано \(imported) тренировок"
        case let .failed(message):
            return "Ошибка: \(message)"
        }
    }
    
    // MARK: - Export Triggers
    
    private func triggerCSVHistoryExport() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: exportStartDate)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: exportEndDate) ?? exportEndDate
        
        let filtered = activities.filter { $0.startDate >= start && $0.startDate <= end }.sorted { $0.startDate < $1.startDate }
        let csv = ExportManager.exportToCSV(activities: filtered)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("tezdav_activities_history.csv")
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            self.profileShareURL = fileURL
            self.isShowingProfileShareSheet = true
        } catch {
            print("Failed to write temporary CSV export: \(error)")
        }
    }
    
    private func triggerJSONBackupExport() {
        let json = ExportManager.exportToJSONBackup(
            activities: activities,
            settings: settingsList,
            weeks: plannedWeeksList,
            segments: allSegmentsList
        )
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("tezdav_full_backup.json")
        do {
            try json.write(to: fileURL, atomically: true, encoding: .utf8)
            self.profileShareURL = fileURL
            self.isShowingProfileShareSheet = true
        } catch {
            print("Failed to write temporary JSON export: \(error)")
        }
    }
    
    private var dailyStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let activeDates = Set(activities.map { calendar.startOfDay(for: $0.startDate) })
        
        var streak = 0
        var checkDate = today
        if activeDates.contains(today) {
            streak = 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
            while activeDates.contains(checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            }
        } else {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if activeDates.contains(yesterday) {
                streak = 1
                checkDate = calendar.date(byAdding: .day, value: -2, to: today)!
                while activeDates.contains(checkDate) {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                }
            }
        }
        return streak
    }
    
    private var weeklyStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        var activeWeeks: Set<Int> = []
        for activity in activities {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: activity.startDate)
            if let year = components.yearForWeekOfYear, let week = components.weekOfYear {
                let weekId = year * 100 + week
                activeWeeks.insert(weekId)
            }
        }
        
        var streak = 0
        var checkDate = today
        
        while true {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: checkDate)
            if let year = components.yearForWeekOfYear, let week = components.weekOfYear {
                let weekId = year * 100 + week
                if activeWeeks.contains(weekId) {
                    streak += 1
                    guard let prevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) else { break }
                    checkDate = prevWeek
                } else {
                    let currentWeekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
                    let currentWeekId = (currentWeekComponents.yearForWeekOfYear ?? 0) * 100 + (currentWeekComponents.weekOfYear ?? 0)
                    if weekId == currentWeekId && streak == 0 {
                        guard let prevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) else { break }
                        checkDate = prevWeek
                        continue
                    }
                    break
                }
            } else {
                break
            }
        }
        return streak
    }
    
    // MARK: - Personal Geography Calculations
    
    private var uniqueCitiesCount: Int {
        var clusters: [CLLocationCoordinate2D] = []
        for act in activities {
            guard let lat = act.startLatitude, let lng = act.startLongitude else { continue }
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            let isNewCluster = !clusters.contains { existing in
                let l1 = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let l2 = CLLocation(latitude: existing.latitude, longitude: existing.longitude)
                return l1.distance(from: l2) <= 15000.0 // 15 km threshold for distinct cities
            }
            if isNewCluster {
                clusters.append(coord)
            }
        }
        return max(1, clusters.count)
    }
    
    private var exploredAreaSqKm: Double {
        var visitedCells = Set<String>()
        for act in activities {
            guard let poly = act.encodedPolyline, !poly.isEmpty else { continue }
            let coords = PolylineEncoder.decode(polyline: poly)
            for coord in coords {
                let latCell = Int(coord.latitude / 0.009)
                let cosLat = cos(coord.latitude * .pi / 180.0)
                let lngCellFactor = cosLat > 0 ? (0.009 / cosLat) : 0.009
                let lngCell = Int(coord.longitude / lngCellFactor)
                visitedCells.insert("\(latCell),\(lngCell)")
            }
        }
        return Double(visitedCells.count)
    }
    
    struct ExtremePoints {
        var north: Double = 38.56
        var south: Double = 38.56
        var east: Double = 68.79
        var west: Double = 68.79
    }
    
    private var extremePoints: ExtremePoints {
        var points = ExtremePoints()
        var hasData = false
        
        for act in activities {
            guard let poly = act.encodedPolyline, !poly.isEmpty else { continue }
            let coords = PolylineEncoder.decode(polyline: poly)
            for coord in coords {
                if !hasData {
                    points.north = coord.latitude
                    points.south = coord.latitude
                    points.east = coord.longitude
                    points.west = coord.longitude
                    hasData = true
                } else {
                    points.north = max(points.north, coord.latitude)
                    points.south = min(points.south, coord.latitude)
                    points.east = max(points.east, coord.longitude)
                    points.west = min(points.west, coord.longitude)
                }
            }
        }
        return points
    }
    
    private var personalGeographySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(Locale.current.identifier.hasPrefix("ru") ? "Уникальные города" : "Unique Cities", systemImage: "building.2.fill")
                Spacer()
                Text("\(uniqueCitiesCount)")
                    .bold()
            }
            
            HStack {
                Label(Locale.current.identifier.hasPrefix("ru") ? "Площадь исследования" : "Explored Area", systemImage: "square.dashed")
                Spacer()
                Text(String(format: "%.1f км²", exploredAreaSqKm))
                    .bold()
            }
            
            Divider()
            
            Text(Locale.current.identifier.hasPrefix("ru") ? "Крайние географические точки:" : "Extreme Geographical Points:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            let pts = extremePoints
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text(Locale.current.identifier.hasPrefix("ru") ? "Север:" : "North:").foregroundColor(.secondary)
                    Text(String(format: "%.5f° N", pts.north)).monospacedDigit()
                }
                GridRow {
                    Text(Locale.current.identifier.hasPrefix("ru") ? "Юг:" : "South:").foregroundColor(.secondary)
                    Text(String(format: "%.5f° N", pts.south)).monospacedDigit()
                }
                GridRow {
                    Text(Locale.current.identifier.hasPrefix("ru") ? "Восток:" : "East:").foregroundColor(.secondary)
                    Text(String(format: "%.5f° E", pts.east)).monospacedDigit()
                }
                GridRow {
                    Text(Locale.current.identifier.hasPrefix("ru") ? "Запад:" : "West:").foregroundColor(.secondary)
                    Text(String(format: "%.5f° E", pts.west)).monospacedDigit()
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
