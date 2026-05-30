import Charts
import SwiftData
import SwiftUI

struct RecordsView: View {
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Query private var userSettings: [UserSettings]
    @Query(sort: \SavedRoute.createdAt, order: .reverse) private var savedRoutes: [SavedRoute]
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
        NavigationStack {
            Group {
                let runningActivities = activities.filter { $0.sportType.lowercased().contains("run") }
                
                if runningActivities.isEmpty {
                    ContentUnavailableView(
                        "Нет рекордов",
                        systemImage: "trophy",
                        description: Text("Синхронизируй хотя бы одну беговую тренировку чтобы увидеть рекорды")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Running Personal Records
                            runningRecordsSection
                            
                            // Dynamic Record Progression Chart
                            recordProgressionSection

                            // Cycling Critical Power Curve
                            cyclingCriticalPowerSection
                            
                            // Riegel Race Predictor Calculator
                            racePredictorSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Records & Projections")
            .onAppear {
                scanAndComputeRecords()
            }
            .sheet(item: $exportItem) { item in
                HeatmapShareSheet(activityItems: [item.image])
            }
        }
    }

    // MARK: - Running Personal Records Section
    private var runningRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Running Personal Records")
                .font(.headline)

            let distances: [(name: String, keyPath: KeyPath<Activity, TimeInterval?>)] = [
                ("1 km", \Activity.best1kTime),
                ("5 km", \Activity.best5kTime),
                ("10 km", \Activity.best10kTime),
                ("Half Marathon", \Activity.bestHalfMarathonTime),
                ("Marathon", \Activity.bestMarathonTime)
            ]

            VStack(spacing: 0) {
                ForEach(distances, id: \.name) { dist in
                    let bestPair = findBestRecord(for: dist.keyPath)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dist.name)
                                .font(.subheadline.weight(.semibold))
                            if let act = bestPair.activity {
                                Text(act.startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if let time = bestPair.time, let act = bestPair.activity {
                            NavigationLink(destination: ActivityDetailView(activity: act)) {
                                HStack(spacing: 4) {
                                    Text(formattedDuration(time))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.primary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text("--:--")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    
                    if dist.name != "Marathon" {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Dynamic Record Progression Chart Section
    private var recordProgressionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Record History")
                    .font(.headline)
                Spacer()
                Picker("Distance", selection: $selectedRunningProgressDistance) {
                    Text("1k").tag("1k")
                    Text("5k").tag("5k")
                    Text("10k").tag("10k")
                }
                .pickerStyle(.menu)
            }

            let progressData = makeProgressionData()
            if progressData.isEmpty {
                Text("Complete activities of this distance with GPS to see history.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Chart {
                        ForEach(progressData) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Pace", point.value / 60.0) // Plot in minutes
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                            
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Pace", point.value / 60.0)
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                    .frame(height: 120)
                    .chartYAxis {
                        AxisMarks(values: .automatic) { value in
                            if let mins = value.as(Double.self) {
                                AxisValueLabel(String(format: "%.0f:00", mins))
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Cycling Critical Power Section
    private var cyclingCriticalPowerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Critical Power Curve")
                .font(.headline)
            
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
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("No cycling power records found.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(spacing: 8) {
                    ForEach(powerCurves, id: \.duration) { cp in
                        let peakPower = activities.compactMap { $0[keyPath: cp.keyPath] }.max() ?? 0.0
                        
                        VStack(spacing: 6) {
                            Text(cp.duration)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(peakPower > 0 ? String(format: "%.0fW", peakPower) : "--")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    // MARK: - Race Predictor Pro (v2) Section
    private var racePredictorSection: some View {
        let baselineSec = Double(baselineHours * 3600 + baselineMinutes * 60 + baselineSeconds)
        let ctl = currentCTL
        let isMetric = activeUserSettings.isMetric
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Race Predictor Pro (v2)")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                // 1. Fitness Card (CTL Info)
                HStack(spacing: 12) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.title2)
                        .foregroundStyle(.orange.gradient)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "Спортивная форма (CTL): %.1f", ctl))
                            .font(.subheadline.weight(.bold))
                        Text("Уровень выносливости: \(enduranceLevel(for: ctl))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                
                // 2. Baseline Picker
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Базовый результат:")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Picker("Baseline Distance", selection: $baselineDistance) {
                            Text("1 км").tag(1000.0)
                            Text("5 км").tag(5000.0)
                            Text("10 км").tag(10000.0)
                            Text("Полумарафон").tag(21097.4)
                            Text("Марафон").tag(42195.0)
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Time wheel pickers
                    HStack {
                        Text("Время:")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Picker("Hours", selection: $baselineHours) {
                                ForEach(0..<10) { h in
                                    Text("\(h) ч").tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60, height: 60)
                            .clipped()
                            
                            Picker("Minutes", selection: $baselineMinutes) {
                                ForEach(0..<60) { m in
                                    Text("\(m) м").tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 65, height: 60)
                            .clipped()
                            
                            Picker("Seconds", selection: $baselineSeconds) {
                                ForEach(0..<60) { s in
                                    Text("\(s) с").tag(s)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60, height: 60)
                            .clipped()
                        }
                    }
                }
                
                Divider()
                
                // 3. Selection Mode (Manual vs Saved Route)
                Picker("Режим целевого трека", selection: $useSavedRoute) {
                    Text("Вручную").tag(false)
                    Text("Маршрут").tag(true)
                }
                .pickerStyle(.segmented)
                
                if useSavedRoute {
                    let runRoutes = runningSavedRoutes
                    if runRoutes.isEmpty {
                        Text("Нет сохраненных беговых маршрутов.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        Picker("Маршрут", selection: $selectedRouteId) {
                            Text("Выберите маршрут...").tag(nil as UUID?)
                            ForEach(runRoutes) { route in
                                let distStr = isMetric ? String(format: "%.1f км", route.totalDistanceMeters / 1000.0) : String(format: "%.1f миль", route.totalDistanceMeters / 1609.34)
                                Text("\(route.name) (\(distStr))")
                                    .tag(route.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedRouteId) { _, newId in
                            if let route = runningSavedRoutes.first(where: { $0.id == newId }) {
                                manualElevationGain = route.totalElevationGain
                            }
                        }
                    }
                }
                
                // 4. Conditions Sliders
                VStack(spacing: 12) {
                    // Temperature Slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Температура воздуха:")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if isMetric {
                                Text(String(format: "%.0f°C", temperatureCelsius))
                                    .font(.caption.weight(.bold))
                            } else {
                                Text(String(format: "%.0f°F", temperatureCelsius * 9.0 / 5.0 + 32.0))
                                    .font(.caption.weight(.bold))
                            }
                        }
                        Slider(value: $temperatureCelsius, in: -5...35, step: 1)
                            .tint(.orange)
                    }
                    
                    // Elevation Gain Slider (Disabled when using route)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Набор высоты:")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if isMetric {
                                Text(String(format: "%.0f м", manualElevationGain))
                                    .font(.caption.weight(.bold))
                            } else {
                                Text(String(format: "%.0f фт", manualElevationGain * 3.28084))
                                    .font(.caption.weight(.bold))
                            }
                        }
                        Slider(value: $manualElevationGain, in: 0...2000, step: 10)
                            .tint(.blue)
                            .disabled(useSavedRoute && selectedRouteId != nil)
                    }
                }
                
                Divider()
                
                // 5. Predictions Table
                if baselineSec <= 0 {
                    Text("Введите корректное базовое время для расчета прогноза.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    let targets: [(name: String, dist: Double)] = {
                        if let route = selectedRoute {
                            return [(route.name, route.totalDistanceMeters)]
                        } else {
                            return [
                                ("5 км", 5000.0),
                                ("10 км", 10000.0),
                                ("Полумарафон", 21097.4),
                                ("Марафон", 42195.0)
                            ]
                        }
                    }()
                    
                    VStack(spacing: 8) {
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
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(target.name)
                                            .font(.subheadline.weight(.semibold))
                                        
                                        // Show average projected pace
                                        let paceDist = isMetric ? 1000.0 : 1609.344
                                        let paceSec = projectedSec / (target.dist / paceDist)
                                        let paceMin = Int(paceSec) / 60
                                        let paceSecRemainder = Int(paceSec) % 60
                                        Text(String(format: "Средний темп: %d:%02d /%@", paceMin, paceSecRemainder, isMetric ? "км" : "миля"))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formattedDuration(projectedSec))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.orange)
                                }
                                .padding(.vertical, 6)
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
                    
                    Divider()
                    
                    Button(action: {
                        withAnimation {
                            showSplits.toggle()
                        }
                    }) {
                        HStack {
                            Text(showSplits ? "Скрыть раскладку темпа" : "Показать раскладку темпа")
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Image(systemName: showSplits ? "chevron.up" : "chevron.down")
                                .font(.subheadline)
                        }
                        .foregroundColor(.orange)
                    }
                    
                    if showSplits {
                        VStack(spacing: 12) {
                            // Splits rendering
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Сплит").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(width: 50, alignment: .leading)
                                    Text("Темп").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                                    Text("Время").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                                    Text("Набор").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(.horizontal, 8)
                                
                                ForEach(currentSplits) { split in
                                    let segmentPaceFactor = split.splitDistance / (isMetric ? 1000.0 : 1609.344)
                                    let paceSec = split.splitDuration / segmentPaceFactor
                                    let paceMin = Int(paceSec) / 60
                                    let paceSecRemainder = Int(paceSec) % 60
                                    
                                    HStack {
                                        Text("\(split.number)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 50, alignment: .leading)
                                        
                                        Text(String(format: "%d:%02d /%@", paceMin, paceSecRemainder, isMetric ? "км" : "миля"))
                                            .font(.subheadline.weight(.semibold))
                                            .frame(width: 90, alignment: .leading)
                                        
                                        Text(formattedDuration(split.cumulativeDuration))
                                            .font(.subheadline.monospacedDigit())
                                            .frame(width: 80, alignment: .leading)
                                        
                                        let elevVal = isMetric ? split.elevationGain : split.elevationGain * 3.28084
                                        Text(elevVal > 0.5 ? String(format: "+%.0f %@", elevVal, isMetric ? "м" : "фт") : "-")
                                            .font(.subheadline)
                                            .foregroundStyle(elevVal > 0.5 ? .green : .secondary)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(split.number % 2 == 0 ? Color.black.opacity(0.05) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            
                            // Export Wristband Button
                            Button(action: {
                                let routeName = selectedRoute?.name ?? (isMetric ? String(format: "Прогноз на %.1f км", targetDist / 1000.0) : String(format: "Прогноз на %.1f миль", targetDist / 1609.34))
                                let distStr = isMetric ? String(format: "%.1f км", targetDist / 1000.0) : String(format: "%.1f миль", targetDist / 1609.34)
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
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Экспортировать Pace Band")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.orange, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundColor(.white)
                                .font(.subheadline.weight(.semibold))
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var currentCTL: Double {
        let summary = DashboardViewModel.summary(from: activities)
        return summary.ctl
    }
    
    private func enduranceLevel(for ctl: Double) -> String {
        if ctl < 25.0 {
            return "Начальный (Low)"
        } else if ctl < 50.0 {
            return "Базовый (Moderate)"
        } else if ctl < 75.0 {
            return "Отличный (Good)"
        } else {
            return "Элитный (Excellent)"
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

struct RacePredictorShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

