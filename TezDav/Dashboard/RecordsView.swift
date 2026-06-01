import Charts
import SwiftData
import SwiftUI

struct RecordsView: View {
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Query private var userSettings: [UserSettings]
    @Query(sort: \SavedRoute.createdAt, order: .reverse) private var savedRoutes: [SavedRoute]
    @Query(sort: \PersonalSegment.name) private var personalSegments: [PersonalSegment]
    @Environment(\.modelContext) private var modelContext
    
    // Riegel Calculator state
    @State private var baselineDistance: Double = 10000.0 // Default 10k
    @State private var baselineHours: Int = 0
    @State private var baselineMinutes: Int = 48
    @State private var baselineSeconds: Int = 0
    
    // Pro predictor state
    @State private var useSavedRoute = false
    @State private var selectedRouteId: UUID? = nil
    @State private var temperatureCelsius: Double = 10.0
    @State private var manualElevationGain: Double = 0.0
    @State private var showSplits = false
    @State private var exportItem: RacePredictorShareItem? = nil
    
    // Dynamic progression chart selection
    @State private var selectedRunningProgressDistance: String = "5k"

    var body: some View {
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        let runningActivities = activities.filter { $0.sportType.lowercased().contains("run") }
        
        Group {
            if runningActivities.isEmpty {
                ContentUnavailableView(
                    isRussian ? "Нет рекордов" : "No Records",
                    systemImage: "trophy.fill",
                    description: Text(isRussian ? "Синхронизируйте хотя бы одну беговую тренировку, чтобы увидеть рекорды" : "Sync at least one running workout to see records")
                )
                .background(AmbientBackgroundView())
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Running Personal Records
                        runningRecordsSection
                        
                        // Dynamic Record Progression Chart
                        recordProgressionSection

                        // Cycling Critical Power Curve
                        cyclingCriticalPowerSection
                        
                        // Personal Route Segments List
                        personalSegmentsSection
                        
                        // Riegel Race Predictor Calculator
                        racePredictorSection
                        
                        Spacer()
                            .frame(height: 120)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            scanAndComputeRecords()
        }
        .sheet(item: $exportItem) { item in
            HeatmapShareSheet(activityItems: [item.image])
        }
    }

    // MARK: - Running Personal Records Section
    private var runningRecordsSection: some View {
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.warning)
                Text(isRussian ? "Личные рекорды (Бег)" : "Running Personal Records")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, 4)

            let distances: [(name: String, keyPath: KeyPath<Activity, TimeInterval?>)] = [
                (isRussian ? "1 км" : "1 km", \Activity.best1kTime),
                (isRussian ? "5 км" : "5 km", \Activity.best5kTime),
                (isRussian ? "10 км" : "10 km", \Activity.best10kTime),
                (isRussian ? "Полумарафон" : "Half Marathon", \Activity.bestHalfMarathonTime),
                (isRussian ? "Марафон" : "Marathon", \Activity.bestMarathonTime)
            ]

            VStack(spacing: 0) {
                ForEach(distances, id: \.name) { dist in
                    let bestPair = findBestRecord(for: dist.keyPath)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(dist.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            if let act = bestPair.activity {
                                Text(act.startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.textTertiaryReadable)
                            }
                        }
                        
                        Spacer()
                        
                        if let time = bestPair.time, let act = bestPair.activity {
                            NavigationLink(destination: ActivityDetailView(activity: act)) {
                                HStack(spacing: 6) {
                                    Text(formattedDuration(time))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.accentPrimary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.textTertiaryReadable)
                                }
                            }
                            .buttonStyle(RecordPressButtonStyle())
                        } else {
                            Text(isRussian ? "Нет данных" : "No data")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textDisabled)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    
                    if dist.name != distances.last?.name {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .liquidGlassCard()
    }

    // MARK: - Dynamic Record Progression Chart Section
    @ViewBuilder
    private func recordProgressionChart(progressData: [ProgressionPoint]) -> some View {
        let chartGradient = LinearGradient(
            colors: [Color.accentPrimary.opacity(0.18), Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
        
        Chart {
            ForEach(progressData) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Pace", point.value / 60.0)
                )
                .foregroundStyle(chartGradient)
                .interpolationMethod(.catmullRom)
            }
            
            ForEach(progressData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Pace", point.value / 60.0)
                )
                .foregroundStyle(Color.accentPrimary)
                .lineStyle(StrokeStyle(lineWidth: 3))
                .interpolationMethod(.catmullRom)
            }
            
            ForEach(progressData) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Pace", point.value / 60.0)
                )
                .symbol(Circle())
            }
        }
        .frame(height: 140)
        .chartYAxis {
            AxisMarks(values: .automatic) { value in
                if let mins = value.as(Double.self) {
                    AxisValueLabel(String(format: "%.0f:00", mins))
                        .foregroundStyle(Color.textTertiaryReadable)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .foregroundStyle(Color.textTertiaryReadable)
            }
        }
    }

    private var recordProgressionSection: some View {
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.accentPrimary)
                    Text(isRussian ? "История рекордов" : "Record History")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
            }
            
            // Custom horizontal selector row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["1k", "5k", "10k"], id: \.self) { dist in
                        Button {
                            HapticManager.trigger(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedRunningProgressDistance = dist
                            }
                        } label: {
                            Text(dist.uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedRunningProgressDistance == dist ? Color.accentPrimary.opacity(0.15) : Color.white.opacity(0.04))
                                .foregroundColor(selectedRunningProgressDistance == dist ? Color.accentPrimary : Color.textSecondaryReadable)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(selectedRunningProgressDistance == dist ? Color.accentPrimary.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            
            let progressData = makeProgressionData()
            if progressData.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.path")
                        .font(.title2)
                        .foregroundStyle(Color.textDisabled)
                    Text(isRussian ? "Выполните тренировки на эту дистанцию с GPS, чтобы увидеть историю." : "Complete activities of this distance with GPS to see history.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiaryReadable)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if NSClassFromString("XCTestCase") == nil {
                        recordProgressionChart(progressData: progressData)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 140)
                            .overlay(
                                Text(isRussian ? "График изменения рекордов" : "Record Progression Chart")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .liquidGlassCard()
    }

    // MARK: - Cycling Critical Power Section
    private var cyclingCriticalPowerSection: some View {
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.warning)
                Text(isRussian ? "Критическая мощность (Вело)" : "Critical Power Curve")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            
            let powerCurves: [(duration: String, keyPath: KeyPath<Activity, Double?>)] = [
                ("5 sec", \Activity.peakPower5s),
                ("1 min", \Activity.peakPower1m),
                ("5 min", \Activity.peakPower5m),
                ("20 min", \Activity.peakPower20m),
                ("60 min", \Activity.peakPower60m)
            ]
            
            let hasAnyPower = activities.contains { $0.peakPower5s != nil }
            if !hasAnyPower {
                VStack(spacing: 8) {
                    Image(systemName: "bolt.slash")
                        .font(.title3)
                        .foregroundStyle(Color.textDisabled)
                    Text(isRussian ? "Показатели мощности не найдены." : "No cycling power records found.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiaryReadable)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
            } else {
                HStack(spacing: 8) {
                    ForEach(powerCurves, id: \.duration) { cp in
                        let peakPower = activities.compactMap { $0[keyPath: cp.keyPath] }.max() ?? 0.0
                        
                        VStack(spacing: 6) {
                            Text(cp.duration)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.textSecondaryReadable)
                            Text(peakPower > 0 ? String(format: "%.0f W", peakPower) : "--")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(peakPower > 0 ? Color.accentPrimary : Color.textDisabled)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(16)
        .liquidGlassCard()
    }

    // MARK: - Personal Segments Section
    private var personalSegmentsSection: some View {
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.accentPrimary)
                Text(isRussian ? "Личные сегменты" : "Personal Segments")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            
            if personalSegments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "flag.slash.fill")
                        .font(.title3)
                        .foregroundStyle(Color.textDisabled)
                    Text(isRussian ? "У вас пока нет личных сегментов.\nВы можете создать их на карте любой тренировки." : "You don't have any personal segments yet.\nYou can create them on any workout map.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiaryReadable)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(personalSegments) { segment in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(segment.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                HStack(spacing: 6) {
                                    Image(systemName: segment.sportType.lowercased().contains("run") ? "figure.run" : "bicycle")
                                        .font(.system(size: 10))
                                        .foregroundStyle(segment.sportType.lowercased().contains("run") ? Color.sportRunning : Color.sportCycling)
                                    Text(String(format: isRussian ? "%.2f км" : "%.2f km", segment.distanceMeters / 1000.0))
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.textTertiaryReadable)
                                }
                            }
                            
                            Spacer()
                            
                            if let bestTime = bestEffortTime(for: segment) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(isRussian ? "Рекорд" : "Record")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.textTertiaryReadable)
                                    Text(formattedDuration(bestTime))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.warning)
                                }
                            } else {
                                Text(isRussian ? "Нет попыток" : "No attempts")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textDisabled)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        
                        if segment.id != personalSegments.last?.id {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .liquidGlassCard()
    }

    // MARK: - Race Predictor Pro (v2) Section
    private var racePredictorSection: some View {
        let baselineSec = Double(baselineHours * 3600 + baselineMinutes * 60 + baselineSeconds)
        let ctl = currentCTL
        let isMetric = activeUserSettings.isMetric
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "figure.run.square.stack")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.orange)
                Text(isRussian ? "Race Predictor Pro (v2)" : "Race Predictor Pro (v2)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 18) {
                // 1. Fitness Card (CTL Info)
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 42, height: 42)
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.orange.gradient)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isRussian ? String(format: "Спортивная форма (CTL): %.1f", ctl) : String(format: "Fitness Form (CTL): %.1f", ctl))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text(isRussian ? "Уровень выносливости: \(enduranceLevel(for: ctl))" : "Endurance Level: \(enduranceLevel(for: ctl))")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textSecondaryReadable)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                
                // 2. Baseline Picker
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(isRussian ? "Базовый результат:" : "Baseline result:")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                    }
                    
                    let distancesOptions: [(name: String, value: Double)] = [
                        (isRussian ? "1 км" : "1 km", 1000.0),
                        (isRussian ? "5 км" : "5 km", 5000.0),
                        (isRussian ? "10 км" : "10 km", 10000.0),
                        (isRussian ? "Полумарафон" : "Half Marathon", 21097.4),
                        (isRussian ? "Марафон" : "Marathon", 42195.0)
                    ]
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(distancesOptions, id: \.value) { opt in
                                Button {
                                    HapticManager.trigger(.light)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        baselineDistance = opt.value
                                    }
                                } label: {
                                    Text(opt.name)
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(baselineDistance == opt.value ? Color.orange.opacity(0.15) : Color.white.opacity(0.04))
                                        .foregroundColor(baselineDistance == opt.value ? Color.orange : Color.textSecondaryReadable)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(baselineDistance == opt.value ? Color.orange.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                    
                    // Time wheel pickers
                    HStack {
                        Text(isRussian ? "Время:" : "Time:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textSecondaryReadable)
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Spacer()
                            HStack(spacing: 4) {
                                HStack(spacing: 0) {
                                    Picker("Hours", selection: $baselineHours) {
                                        ForEach(0..<10) { h in
                                            Text("\(h)").tag(h)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 45, height: 60)
                                    .clipped()
                                    
                                    Text("ч")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.textTertiaryReadable)
                                }
                                
                                HStack(spacing: 0) {
                                    Picker("Minutes", selection: $baselineMinutes) {
                                        ForEach(0..<60) { m in
                                            Text("\(m)").tag(m)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 48, height: 60)
                                    .clipped()
                                    
                                    Text("м")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.textTertiaryReadable)
                                }
                                
                                HStack(spacing: 0) {
                                    Picker("Seconds", selection: $baselineSeconds) {
                                        ForEach(0..<60) { s in
                                            Text("\(s)").tag(s)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 45, height: 60)
                                    .clipped()
                                    
                                    Text("с")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.textTertiaryReadable)
                                }
                            }
                            .padding(.horizontal, 10)
                            .background(Color.white.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                
                // 3. Selection Mode (Manual vs Saved Route)
                VStack(alignment: .leading, spacing: 10) {
                    Text(isRussian ? "Целевая трасса" : "Target Track")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    
                    HStack(spacing: 4) {
                        Button {
                            HapticManager.trigger(.light)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                useSavedRoute = false
                            }
                        } label: {
                            Text(isRussian ? "Вручную" : "Manual")
                                .font(.system(size: 12, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(useSavedRoute ? Color.clear : Color.white.opacity(0.08))
                                .foregroundColor(useSavedRoute ? Color.textSecondaryReadable : Color.white)
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            HapticManager.trigger(.light)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                useSavedRoute = true
                            }
                        } label: {
                            Text(isRussian ? "Маршрут" : "Saved Route")
                                .font(.system(size: 12, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(useSavedRoute ? Color.white.opacity(0.08) : Color.clear)
                                .foregroundColor(useSavedRoute ? Color.white : Color.textSecondaryReadable)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(3)
                    .background(Color.black.opacity(0.2))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    
                    if useSavedRoute {
                        let runRoutes = runningSavedRoutes
                        if runRoutes.isEmpty {
                            Text(isRussian ? "Нет сохраненных беговых маршрутов." : "No saved running routes.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textDisabled)
                                .padding(.vertical, 4)
                        } else {
                            Menu {
                                Button(isRussian ? "Выберите маршрут..." : "Select route...") {
                                    selectedRouteId = nil
                                }
                                ForEach(runRoutes) { route in
                                    Button {
                                        selectedRouteId = route.id
                                        manualElevationGain = route.totalElevationGain
                                    } label: {
                                        let distStr = isMetric ? String(format: "%.1f км", route.totalDistanceMeters / 1000.0) : String(format: "%.1f miles", route.totalDistanceMeters / 1609.34)
                                        Text("\(route.name) (\(distStr))")
                                    }
                                }
                            } label: {
                                HStack {
                                    if let selectedRoute = runningSavedRoutes.first(where: { $0.id == selectedRouteId }) {
                                        let distStr = isMetric ? String(format: "%.1f км", selectedRoute.totalDistanceMeters / 1000.0) : String(format: "%.1f miles", selectedRoute.totalDistanceMeters / 1609.34)
                                        Text("\(selectedRoute.name) (\(distStr))")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.textPrimary)
                                    } else {
                                        Text(isRussian ? "Выберите маршрут..." : "Select route...")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.textTertiaryReadable)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(Color.textTertiaryReadable)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                
                // 4. Conditions Sliders
                VStack(spacing: 14) {
                    // Temperature Slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(isRussian ? "Температура воздуха:" : "Air Temperature:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.textSecondaryReadable)
                            Spacer()
                            if isMetric {
                                Text(String(format: "%.0f°C", temperatureCelsius))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.orange)
                            } else {
                                Text(String(format: "%.0f°F", temperatureCelsius * 9.0 / 5.0 + 32.0))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.orange)
                            }
                        }
                        Slider(value: $temperatureCelsius, in: -5...35, step: 1)
                            .tint(.orange)
                    }
                    
                    // Elevation Gain Slider (Disabled when using route)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(isRussian ? "Набор высоты:" : "Elevation Gain:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.textSecondaryReadable)
                            Spacer()
                            if isMetric {
                                Text(String(format: "%.0f м", manualElevationGain))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.accentPrimary)
                            } else {
                                Text(String(format: "%.0f ft", manualElevationGain * 3.28084))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.accentPrimary)
                            }
                        }
                        Slider(value: $manualElevationGain, in: 0...2000, step: 10)
                            .tint(Color.accentPrimary)
                            .disabled(useSavedRoute && selectedRouteId != nil)
                    }
                }
                
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                
                // 5. Predictions Table
                if baselineSec <= 0 {
                    Text(isRussian ? "Введите корректное базовое время для расчета прогноза." : "Enter a valid baseline time to calculate prediction.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textDisabled)
                } else {
                    let targets: [(name: String, dist: Double)] = {
                        if let route = selectedRoute {
                            return [(route.name, route.totalDistanceMeters)]
                        } else {
                            return [
                                (isRussian ? "5 км" : "5 km", 5000.0),
                                (isRussian ? "10 км" : "10 km", 10000.0),
                                (isRussian ? "Полумарафон" : "Half Marathon", 21097.4),
                                (isRussian ? "Марафон" : "Marathon", 42195.0)
                            ]
                        }
                    }()
                    
                    VStack(spacing: 8) {
                        if targets.contains(where: { $0.dist > 42195.0 }) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                                Text(isRussian ? "Формула Риегеля теряет точность на дистанциях больше марафона" : "Riegel formula loses accuracy on distances exceeding a marathon")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.textSecondaryReadable)
                            }
                            .padding(8)
                            .background(Color.yellow.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.bottom, 4)
                        }

                        ForEach(targets, id: \.name) { target in
                            if useSavedRoute || abs(target.dist - baselineDistance) > 10 {
                                let projectedSec = RacePredictorEngine.predictTime(
                                    baseDistance: baselineDistance,
                                    baseTime: baselineSec,
                                    targetDistance: target.dist,
                                    ctl: ctl,
                                    elevationGain: useSavedRoute ? (selectedRoute?.totalElevationGain ?? 0.0) : manualElevationGain,
                                    temperatureCelsius: temperatureCelsius
                                )
                                
                                let speedMps = target.dist / max(1.0, projectedSec)
                                let isUnrealistic = speedMps > 7.5 // Faster than 2:13 min/km
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(target.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.textPrimary)
                                        
                                        // Show average projected pace
                                        let paceDist = isMetric ? 1000.0 : 1609.344
                                        let paceSec = projectedSec / (target.dist / paceDist)
                                        let paceMin = Int(paceSec) / 60
                                        let paceSecRemainder = Int(paceSec) % 60
                                        Text(String(format: isRussian ? "Средний темп: %d:%02d /%@" : "Avg pace: %d:%02d /%@", paceMin, paceSecRemainder, isMetric ? "км" : "mi"))
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.textTertiaryReadable)
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 8) {
                                        if isUnrealistic {
                                            Text(isRussian ? "Недостоверно" : "Unrealistic")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.red, in: Capsule())
                                        }
                                        Text(formattedDuration(projectedSec))
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.orange)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(Color.white.opacity(0.02))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    // Splits Table and Export Action
                    let targetDist = selectedRoute?.totalDistanceMeters ?? (baselineDistance == 10000.0 ? 10000.0 : 10000.0) // Predict splits for 10k by default or selected route
                    let totalElev = selectedRoute?.totalElevationGain ?? manualElevationGain
                    let elevProfile = selectedRoute?.elevationProfile ?? []
                    let currentSplits = RacePredictorEngine.generateSplits(
                        baseDistance: baselineDistance,
                        baseTime: baselineSec,
                        targetDistance: targetDist,
                        ctl: ctl,
                        totalElevationGain: totalElev,
                        temperatureCelsius: temperatureCelsius,
                        elevationProfile: elevProfile,
                        isMetric: isMetric
                    )
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                    
                    Button(action: {
                        HapticManager.trigger(.light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            showSplits.toggle()
                        }
                    }) {
                        HStack {
                            Text(showSplits ? (isRussian ? "Скрыть раскладку темпа" : "Hide Pace Splits") : (isRussian ? "Показать раскладку темпа" : "Show Pace Splits"))
                                .font(.system(size: 13, weight: .bold))
                            Spacer()
                            Image(systemName: showSplits ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.orange)
                    }
                    .buttonStyle(RecordPressButtonStyle())
                    
                    if showSplits {
                        VStack(spacing: 14) {
                            // Splits rendering
                            VStack(spacing: 6) {
                                HStack {
                                    Text(isRussian ? "Сплит" : "Split").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.textTertiaryReadable).frame(width: 44, alignment: .leading)
                                    Text(isRussian ? "Темп" : "Pace").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.textTertiaryReadable).frame(width: 90, alignment: .leading)
                                    Text(isRussian ? "Время" : "Time").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.textTertiaryReadable).frame(width: 80, alignment: .leading)
                                    Text(isRussian ? "Набор" : "Gain").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.textTertiaryReadable).frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(.horizontal, 8)
                                
                                ForEach(currentSplits) { split in
                                    let segmentPaceFactor = split.splitDistance / (isMetric ? 1000.0 : 1609.344)
                                    let paceSec = split.splitDuration / segmentPaceFactor
                                    let paceMin = Int(paceSec) / 60
                                    let paceSecRemainder = Int(paceSec) % 60
                                    
                                    HStack {
                                        Text("\(split.number)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.textTertiaryReadable)
                                            .frame(width: 44, alignment: .leading)
                                        
                                        Text(String(format: "%d:%02d /%@", paceMin, paceSecRemainder, isMetric ? "км" : "mi"))
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color.textPrimary)
                                            .frame(width: 90, alignment: .leading)
                                        
                                        Text(formattedDuration(split.cumulativeDuration))
                                            .font(.system(size: 12).monospacedDigit())
                                            .foregroundStyle(Color.textPrimary)
                                            .frame(width: 80, alignment: .leading)
                                        
                                        let elevVal = isMetric ? split.elevationGain : split.elevationGain * 3.28084
                                        Text(elevVal > 0.5 ? String(format: "+%.0f %@", elevVal, isMetric ? "м" : "ft") : "-")
                                            .font(.system(size: 12))
                                            .foregroundStyle(elevVal > 0.5 ? Color.accentPrimary : Color.textDisabled)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(split.number % 2 == 0 ? Color.white.opacity(0.04) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            
                            // Export Wristband Button
                            Button(action: {
                                HapticManager.trigger(.medium)
                                let routeName = selectedRoute?.name ?? (isMetric ? String(format: "Прогноз на %.1f км", targetDist / 1000.0) : String(format: "Прогноз на %.1f миль", targetDist / 1609.34))
                                let distStr = isMetric ? String(format: "%.1f км", targetDist / 1000.0) : String(format: "%.1f miles", targetDist / 1609.34)
                                let predictedSec = RacePredictorEngine.predictTime(
                                    baseDistance: baselineDistance,
                                    baseTime: baselineSec,
                                    targetDistance: targetDist,
                                    ctl: ctl,
                                    elevationGain: totalElev,
                                    temperatureCelsius: temperatureCelsius
                                )
                                let paceBandImage = PacingWristbandExporter.render(
                                    title: routeName,
                                    targetDistance: distStr,
                                    targetTime: formattedDuration(predictedSec),
                                    splits: currentSplits,
                                    isMetric: isMetric
                                )
                                exportItem = RacePredictorShareItem(image: paceBandImage)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text(isRussian ? "Экспортировать Pace Band" : "Export Pace Band")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [Color.orange, Color(hex: "EA580C")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .foregroundColor(.white)
                                .font(.system(size: 13, weight: .bold))
                                .clipShape(Capsule())
                                .shadow(color: Color.orange.opacity(0.25), radius: 8, y: 3)
                            }
                            .buttonStyle(RecordPressButtonStyle())
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.01))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(16)
        .liquidGlassCard()
    }
    
    private var currentCTL: Double {
        let summary = DashboardViewModel.summary(from: activities)
        return summary.ctl
    }
    
    private func enduranceLevel(for ctl: Double) -> String {
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        if ctl < 25.0 {
            return isRussian ? "Начальный (Low)" : "Low (Beginner)"
        } else if ctl < 50.0 {
            return isRussian ? "Базовый (Moderate)" : "Moderate (Base)"
        } else if ctl < 75.0 {
            return isRussian ? "Отличный (Good)" : "Good (Advanced)"
        } else {
            return isRussian ? "Элитный (Excellent)" : "Excellent (Elite)"
        }
    }
    
    private var runningSavedRoutes: [SavedRoute] {
        savedRoutes.filter { $0.sportType == "Run" }
    }
    
    private var selectedRoute: SavedRoute? {
        guard useSavedRoute, let routeId = selectedRouteId else { return nil }
        return runningSavedRoutes.first { $0.id == routeId }
    }
    
    private var activeUserSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }

    // MARK: - Helper Methods & Algorithms

    private func findBestRecord(for keyPath: KeyPath<Activity, TimeInterval?>) -> (time: TimeInterval?, activity: Activity?) {
        let sortedPairs = activities.filter { $0[keyPath: keyPath] != nil }
        guard let bestAct = sortedPairs.min(by: { $0[keyPath: keyPath]! < $1[keyPath: keyPath]! }) else {
            return (nil, nil)
        }
        return (bestAct[keyPath: keyPath], bestAct)
    }

    struct ProgressionPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private func makeProgressionData() -> [ProgressionPoint] {
        let keyPath: KeyPath<Activity, TimeInterval?> = {
            switch selectedRunningProgressDistance {
            case "1k": return \Activity.best1kTime
            case "10k": return \Activity.best10kTime
            default: return \Activity.best5kTime
            }
        }()
        
        let validActs = activities.filter { $0[keyPath: keyPath] != nil }.sorted { $0.startDate < $1.startDate }
        guard !validActs.isEmpty else { return [] }
        
        var points: [ProgressionPoint] = []
        var bestSoFar = Double.infinity
        
        for act in validActs {
            if let val = act[keyPath: keyPath], val < bestSoFar {
                bestSoFar = val
                points.append(ProgressionPoint(date: act.startDate, value: val))
            }
        }
        
        return points
    }

    private func scanAndComputeRecords() {
        // Runs dynamic check on appear to scan SwiftData and calculate missing splits if streams are present
        Task {
            let runToScan = activities.filter { $0.sportType.lowercased().contains("run") && $0.best1kTime == nil && $0.streamsImported }
            let rideToScan = activities.filter { $0.sportType.lowercased().contains("ride") && $0.peakPower5s == nil && $0.streamsImported }
            
            let totalToScan = runToScan + rideToScan
            guard !totalToScan.isEmpty else { return }
            
            var newRecordsFound = false
            for act in totalToScan {
                let actId = act.stravaId
                let descriptor = FetchDescriptor<ActivityStreamSample>(
                    predicate: #Predicate { $0.activityId == actId }
                )
                if let samples = try? modelContext.fetch(descriptor), !samples.isEmpty {
                    PersonalRecordCalculator.calculateAndSetRecords(for: act, samples: samples)
                    SegmentMatcher.matchSegments(for: act, samples: samples, context: modelContext)
                    PersonalSegmentMatcher.matchPersonalSegments(for: act, samples: samples, context: modelContext)
                    newRecordsFound = true
                }
            }
            
            try? modelContext.save()
            
            if newRecordsFound {
                HapticManager.trigger(.medium)
            }
            
            // Set Riegel baseline time automatically based on best 10k (if exists)
            let best10k = findBestRecord(for: \Activity.best10kTime)
            if let best10kTime = best10k.time {
                let hours = Int(best10kTime) / 3600
                let minutes = (Int(best10kTime) % 3600) / 60
                let seconds = Int(best10kTime) % 60
                
                await MainActor.run {
                    self.baselineDistance = 10000.0
                    self.baselineHours = hours
                    self.baselineMinutes = minutes
                    self.baselineSeconds = seconds
                }
            }
        }
    }

    private func bestEffortTime(for segment: PersonalSegment) -> TimeInterval? {
        let userEfforts = segment.efforts.filter { !$0.isMock }
        return userEfforts.map { $0.elapsedTime }.min()
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}

// MARK: - Press Gesture style for premium clicks
struct RecordPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct RacePredictorShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}


