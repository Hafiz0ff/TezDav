// swiftlint:disable cyclomatic_complexity
import Charts
import MapKit
import SwiftData
import SwiftUI

// Struct to represent colored map segments for the pace gradient
struct MapSegment: Identifiable, Sendable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}

// Struct to represent splits in splits section, declared at top-level to avoid compiler type checking confusion
struct KilometerSplit: Identifiable, Sendable {
    let id = UUID()
    let index: Int
    let pace: Double // seconds per km
    let avgHeartRate: Double?
    let elevationChange: Double
}

struct ActivityDetailView: View {
    var activity: Activity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Query all activities to compute chronological CTL/ATL deltas and similar comparisons
    @Query(sort: \Activity.startDate, order: .forward) private var allActivities: [Activity]
    // Query stream samples for this activity
    @Query private var streamSamples: [ActivityStreamSample]
    // Query user settings
    @Query private var userSettings: [UserSettings]
    // Query all interval segments
    @Query private var allSegments: [IntervalSegment]
    // Query all segment efforts
    @Query private var allSegmentEfforts: [SegmentEffort]

    @State private var isLoadingStreams = false
    @State private var streamLoadingError: String? = nil
    @State private var selectedChartTab: ChartTab = .heartRate
    @State private var isMapExpanded = false
    @State private var showCreatePersonalSegment = false
    @State private var cameraCenter: CLLocationCoordinate2D? = nil
    @State private var cameraZoom: Float? = nil
    @State private var cameraCenterExpanded: CLLocationCoordinate2D? = nil
    @State private var cameraZoomExpanded: Float? = nil
    
    @State private var shareURL: URL? = nil
    @State private var isShowingShareSheet = false
    @State private var isShowingComparison = false
    @State private var isShowingWorkoutCardShare = false
    @State private var selectedPowerPoint: PowerPoint? = nil
    @State private var selectedDynamicsTab: Int = 0
    @State private var selectedDynamicsDistance: Double? = nil
    
    private var activitySegments: [IntervalSegment] {
        allSegments.filter { $0.activityId == activity.stravaId }.sorted { $0.segmentIndex < $1.segmentIndex }
    }

    private var matchedSegmentEfforts: [SegmentEffort] {
        allSegmentEfforts.filter { $0.activityId == activity.stravaId }.sorted { $0.elapsedTime < $1.elapsedTime }
    }

    private let config = StravaConfig.fromBundle()
    private let tokenStore = KeychainTokenStore()

    // Enums for charts selection
    enum ChartTab: String, CaseIterable, Identifiable {
        case heartRate = "Пульс"
        case pace = "Темп"
        case elevation = "Высота"
        case power = "Мощность"

        var id: String { self.rawValue }
    }

    init(activity: Activity) {
        self.activity = activity
        let id = activity.stravaId
        self._streamSamples = Query(
            filter: #Predicate<ActivityStreamSample> { sample in
                sample.activityId == id
            },
            sort: \ActivityStreamSample.offsetSeconds,
            order: .forward
        )
    }

    private var activeUserSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }

    var body: some View {
        Group {
            if activity.source == "strava" && !activity.streamsImported {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Загрузка высокоточных метрик...")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if isLoadingStreams {
                        Text("Получение маршрута и данных датчиков из Strava...")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }

                    if let streamLoadingError {
                        Text(streamLoadingError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding()

                        Button("Повторить загрузку данных") {
                            triggerStreamFetch()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    triggerStreamFetch()
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Section 1: Header
                        headerSection

                        // Section 2: Route Map
                        mapSection

                        // Section 3: Key Metrics Grid
                        metricsGridSection

                        // Hike stats (Naismith's rule)
                        if activity.sportType.lowercased().contains("walk") || activity.sportType.lowercased().contains("hike") {
                            hikeStatisticsSection
                        }

                        // Section 4: Swift Charts
                        chartsSection

                        if activeUserSettings.appMode == .pro {
                            if activity.sportType.lowercased() == "run" && (activity.averageCadence ?? 0) > 0 {
                                runningDynamicsSection
                            }

                            // Section 5: Splits Table (for distance >= 1km, excluding swim)
                            if activity.distanceMeters >= 1000 && !activity.sportType.lowercased().contains("swim") {
                                splitsSection
                            }

                            // Section 6: Heart Rate Zones
                            if activity.averageHeartRate != nil {
                                heartRateZonesSection
                            }

                            // Section 7: Training Load (TRIMP, TSS, CTL/ATL impact)
                            trainingLoadSection

                            // Section 8: Similar Activities Comparison
                            similarActivitiesSection
                            
                            // Section 9: Interval Analysis
                            if activitySegments.count >= 3 {
                                intervalAnalysisSection
                            }

                            // Section 10: Power Curve
                            if hasPowerCurveData {
                                activityPowerCurveSection
                            }

                            // Section 11: Matched Segments
                            matchedSegmentsSection
                        } else {
                            // Casual mode additions: we still want splits and heart rate zones if they exist!
                            if activity.distanceMeters >= 1000 && !activity.sportType.lowercased().contains("swim") {
                                splitsSection
                            }
                            if activity.averageHeartRate != nil {
                                heartRateZonesSection
                            }
                        }
                    }
                    .padding()
                }
                .onAppear {
                    if activity.averageStrideLength == nil {
                        RunningDynamicsEngine.enrich(activity: activity, samples: streamSamples)
                        try? modelContext.save()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                isShowingWorkoutCardShare = true
                            } label: {
                                Label("Поделиться карточкой", systemImage: "square.and.arrow.up.on.square")
                            }
                            
                            Button {
                                triggerGPXExport()
                            } label: {
                                Label("Экспорт GPX трека", systemImage: "map")
                            }
                            
                            Button {
                                triggerCSVExport()
                            } label: {
                                Label("Экспорт CSV потока", systemImage: "tablecells")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(isPresented: $isShowingWorkoutCardShare) {
                    WorkoutCardShareView(activity: activity)
                }
                .sheet(isPresented: $isShowingShareSheet) {
                    if let url = shareURL {
                        ShareSheet(activityItems: [url])
                    }
                }
                .sheet(isPresented: $isShowingComparison) {
                    comparisonSheet
                }
            }
        }
    }

    // MARK: - Section 1: Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.name)
                        .font(.title2.weight(.bold))
                    
                    HStack(spacing: 6) {
                        Image(systemName: sportIconName(activity.sportType))
                        Text(AppLanguage.sportName(activity.sportType))
                        Text("·")
                        Text(activity.startDate.formatted(date: .long, time: .shortened))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            
            let isNullIsland = activity.startLatitude.map { abs($0) < 0.000001 } == true && activity.startLongitude.map { abs($0) < 0.000001 } == true
            
            if isNullIsland {
                HStack(spacing: 8) {
                    Text(AppLanguage.isRussian ? "Погода: Нет данных" : "Weather: No data")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.top, 4)
            } else if let weather = activity.weatherSnapshot {
                HStack(spacing: 8) {
                    Text(weatherConditionIcon(weather.condition))
                    Text(String(format: "%.1f°C", weather.temperature))
                        .fontWeight(.semibold)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(String(format: "💧 %.0f%%", weather.humidity))
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(String(format: "💨 %.1f м/с", weather.windSpeed))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.top, 4)
            }
            
            Divider()
        }
    }

    private func weatherConditionIcon(_ condition: String) -> String {
        switch condition {
        case "Clear": return "☀️"
        case "Cloudy": return "☁️"
        case "Fog": return "🌫️"
        case "Drizzle", "Rain", "RainShowers": return "🌧️"
        case "Snow": return "❄️"
        case "Thunderstorm": return "⛈️"
        default: return "☀️"
        }
    }

    // MARK: - Section 2: Route Map
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Карта маршрута")
                .font(.headline)
            
            let gpsCoordinates = validGpsCoordinates
            if gpsCoordinates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Маршрут недоступен для этой тренировки.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                let segments = makeMapSegments(from: streamSamples)
                VStack(spacing: 8) {
                    if NSClassFromString("XCTestCase") == nil {
                        TezDavMapView(
                            segments: segments,
                            showStartEndMarkers: true,
                            cameraCenter: $cameraCenter,
                            cameraZoom: $cameraZoom
                        )
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            Button {
                                isMapExpanded = true
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .padding(8)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .padding(8),
                            alignment: .topTrailing
                        )
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 220)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "map")
                                        .font(.title)
                                        .foregroundColor(.purple)
                                    Text("Карта загружена")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                    
                    HStack {
                        Spacer()
                        Button {
                            showCreatePersonalSegment = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                Text(AppLanguage.isRussian ? "Создать личный сегмент" : "Create Personal Segment")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.purple)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.purple.opacity(0.1), in: Capsule())
                        }
                    }
                }
                .sheet(isPresented: $isMapExpanded) {
                    NavigationStack {
                        TezDavMapView(
                            segments: segments,
                            showStartEndMarkers: true,
                            cameraCenter: $cameraCenterExpanded,
                            cameraZoom: $cameraZoomExpanded
                        )
                        .navigationTitle("Маршрут")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Закрыть") {
                                    isMapExpanded = false
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showCreatePersonalSegment) {
                    CreatePersonalSegmentView(activity: activity, samples: streamSamples)
                }

                let isWalkOrHike = activity.sportType.lowercased().contains("walk") || activity.sportType.lowercased().contains("hike")
                HStack {
                    Spacer()
                    if isWalkOrHike {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle().fill(Color(hue: 0.75, saturation: 0.9, brightness: 0.9)).frame(width: 8, height: 8)
                                Text(AppLanguage.isRussian ? "Низкая высота" : "Low Elevation").font(.caption).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color(hue: 0.55, saturation: 0.9, brightness: 0.9)).frame(width: 8, height: 8)
                                Text(AppLanguage.isRussian ? "Средняя высота" : "Medium").font(.caption).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color(hue: 0.35, saturation: 0.9, brightness: 0.9)).frame(width: 8, height: 8)
                                Text(AppLanguage.isRussian ? "Высокая высота" : "High Elevation").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle().fill(.red).frame(width: 8, height: 8)
                                Text(AppLanguage.isRussian ? "Медленно" : "Slow").font(.caption).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(.yellow).frame(width: 8, height: 8)
                                Text(AppLanguage.isRussian ? "Средне" : "Average").font(.caption).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(.green).frame(width: 8, height: 8)
                                Text(AppLanguage.isRussian ? "Быстро" : "Fast").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Section 3: Key Metrics Grid
    private var metricsGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ключевые метрики")
                .font(.headline)

            let isCycling = activity.sportType.lowercased().contains("ride")
            let isSwim = activity.sportType.lowercased().contains("swim")
            
            let avgSpeed = activity.averageSpeed ?? 0
            
            // Standard columns: 3x2 grid
            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]

            let isMetric = activeUserSettings.isMetric
            let distDivider = isMetric ? 1000.0 : 1609.344
            let distUnit = isMetric ? "км" : "миль"
            let speedMultiplier = isMetric ? 3.6 : 2.23694
            let speedUnit = isMetric ? "км/ч" : "миль/ч"
            let paceUnitValue = isMetric ? 1000.0 : 1609.344
            let paceUnitLabel = isMetric ? " /км" : " /милю"
            let elevMultiplier = isMetric ? 1.0 : 3.28084
            let elevUnit = isMetric ? "м" : "фт"

            LazyVGrid(columns: columns, spacing: 12) {
                // Tile 1: Distance
                MetricCard(title: "Дистанция", value: String(format: "%.2f \(distUnit)", activity.distanceMeters / distDivider))

                // Tile 2: Duration
                MetricCard(title: "Время", value: formattedDuration(activity.movingTime))

                // Tile 3: Average Pace/Speed
                if isSwim {
                    let pace100m = avgSpeed > 0 ? (100.0 / avgSpeed) : 0
                    MetricCard(title: "Средний темп", value: formattedPace(pace100m) + " /100 м")
                } else if isCycling {
                    MetricCard(title: "Средняя скорость", value: String(format: "%.1f \(speedUnit)", avgSpeed * speedMultiplier))
                } else {
                    let paceKm = avgSpeed > 0 ? (paceUnitValue / avgSpeed) : 0
                    MetricCard(title: "Средний темп", value: formattedPace(paceKm) + paceUnitLabel)
                }

                // Tile 4: Average Heart Rate
                MetricCard(title: "Средний пульс", value: activity.averageHeartRate.map { String(format: "%.0f уд/мин", $0) } ?? "--")

                // Tile 5: Elevation Gain
                MetricCard(title: "Набор высоты", value: String(format: "%.0f \(elevUnit)", activity.elevationGain * elevMultiplier))

                // Tile 6: Average Cadence
                MetricCard(title: "Каденс", value: activity.averageCadence.map { String(format: "%.0f об/мин", $0) } ?? "--")
            }

            // Cycling Power Metrics (NP, Avg Power)
            if isCycling && (activity.averagePower != nil || hasPowerStream) {
                HStack(spacing: 12) {
                    let powerStream = streamSamples.compactMap { $0.power }
                    let np = calculateNormalizedPower(from: powerStream) ?? activity.averagePower
                    
                    MetricCard(
                        title: "Средняя мощность",
                        value: activity.averagePower.map { String(format: "%.0f Вт", $0) } ?? "--"
                    )
                    
                    MetricCard(
                        title: "Нормализованная мощность (NP)",
                        value: np.map { String(format: "%.0f Вт", $0) } ?? "--"
                    )
                }
            }
        }
    }

    // MARK: - Section 4: Charts Section
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Графики тренировки")
                .font(.headline)

            let availableTabs: [ChartTab] = {
                var tabs: [ChartTab] = [.elevation]
                if activity.averageHeartRate != nil { tabs.append(.heartRate) }
                if !activity.sportType.lowercased().contains("swim") { tabs.append(.pace) }
                if hasPowerStream { tabs.append(.power) }
                return tabs.sorted { $0.rawValue < $1.rawValue }
            }()

            Picker("Показатель графика", selection: $selectedChartTab) {
                ForEach(availableTabs) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .onAppear {
                if !availableTabs.contains(selectedChartTab), let first = availableTabs.first {
                    selectedChartTab = first
                }
            }

            let chartData = makeChartData()
            if chartData.isEmpty {
                Text("Нет данных для этого графика.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(height: 160)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    let isMetric = activeUserSettings.isMetric
                    let chartXLabel = isMetric ? "Дистанция (км)" : "Дистанция (мили)"
                    let chartXUnit = isMetric ? "%.1f км" : "%.1f мили"
                    let isRussian = AppLanguage.isRussian
                    let accessibilityLabelText: String = {
                        switch selectedChartTab {
                        case .heartRate: return isRussian ? "Пульс" : "Heart Rate"
                        case .pace: return isRussian ? "Темп" : "Темп"
                        case .elevation: return isRussian ? "Высота" : "Elevation"
                        case .power: return isRussian ? "Мощность" : "Power"
                        }
                    }()
                    
                    if NSClassFromString("XCTestCase") == nil {
                        Chart {
                            ForEach(chartData) { point in
                                LineMark(
                                    x: .value(chartXLabel, point.x),
                                    y: .value(selectedChartTab.rawValue, point.y)
                                )
                                .foregroundStyle(chartColor(selectedChartTab))
                                .accessibilityLabel(accessibilityLabelText)
                                .accessibilityValue(String(format: isRussian ? "%@ на расстоянии %.2f \(isMetric ? "км" : "миль")" : "%@ at distance %.2f \(isMetric ? "km" : "mi")", formatValue(point.y, tab: selectedChartTab), point.x))
                                
                                AreaMark(
                                    x: .value(chartXLabel, point.x),
                                    y: .value(selectedChartTab.rawValue, point.y)
                                )
                                .foregroundStyle(chartColor(selectedChartTab).opacity(0.15))
                            }
                        }
                        .frame(height: 160)
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                if let km = value.as(Double.self) {
                                    AxisValueLabel(String(format: chartXUnit, km))
                                }
                            }
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 160)
                            .overlay(
                                Text("График: \(selectedChartTab.rawValue.lowercased())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            )
                    }
                    
                    // Chart Metrics footer
                    HStack {
                        let values = chartData.map { $0.y }
                        let average = values.reduce(0, +) / Double(values.count)
                        let maximum = values.max() ?? 0
                        
                        VStack(alignment: .leading) {
                            Text("СРЕДНЕЕ")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(formatValue(average, tab: selectedChartTab))
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("МАКСИМУМ")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(formatValue(maximum, tab: selectedChartTab))
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Section 5: Splits Section
    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(activeUserSettings.isMetric ? "Разбивка по километрам" : "Разбивка по милям")
                .font(.headline)

            let splits = calculateKilometerSplits()
            if splits.isEmpty {
                Text("Недостаточно данных для расчета сплитов.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                SplitsSectionView(splits: splits, isMetric: activeUserSettings.isMetric)
            }
        }
    }

    // MARK: - Section 6: Heart Rate Zones
    private var heartRateZonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Пульсовые зоны")
                .font(.headline)

            let maxHR = activeUserSettings.maxHeartRate
            let zoneTimes = calculateHeartRateZoneTimes(maxHR: maxHR)
            let totalHrTime = zoneTimes.reduce(0, +)

            if totalHrTime == 0 {
                Text("Нет данных о пульсе.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(0..<5) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Зона \(index + 1)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(zoneColor(index))
                                Spacer()
                                Text(formattedDuration(TimeInterval(zoneTimes[index])))
                                    .font(.subheadline)
                                Text(String(format: "(%.0f%%)", (totalHrTime > 0 ? (Double(zoneTimes[index]) / Double(totalHrTime)) : 0.0) * 100))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.tertiary.opacity(0.5))
                                    Capsule()
                                        .fill(zoneColor(index))
                                        .frame(width: geo.size.width * CGFloat(totalHrTime > 0 ? (Double(zoneTimes[index]) / Double(totalHrTime)) : 0.0))
                                }
                            }
                            .frame(height: 8)
                            
                            Text(zoneBpmRange(index, maxHR: maxHR))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Section 7: Training Load
    private var trainingLoadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Эффект тренировки")
                .font(.headline)

            let isCycling = activity.sportType.lowercased().contains("ride")
            let powerStream = streamSamples.compactMap { $0.power }
            let np = calculateNormalizedPower(from: powerStream) ?? activity.averagePower
            let tss = calculateTSS(duration: activity.movingTime, np: np, ftp: activeUserSettings.cyclingFTP)

            let deltas = calculateCTLATLDeltas()

            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    Text("TRIMP")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f", activity.trimp))
                        .font(.title3.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                if isCycling && tss != nil {
                    VStack(spacing: 6) {
                        Text("TSS")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f", tss!))
                            .font(.title3.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

                VStack(spacing: 6) {
                    Text("Δ CTL")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%+.1f", deltas.ctl))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(deltas.ctl >= 0 ? .green : .red)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                VStack(spacing: 6) {
                    Text("Δ ATL")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%+.1f", deltas.atl))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(deltas.atl >= 0 ? .orange : .red)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Section 8: Similar Activities
    private var similarActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Похожие тренировки")
                .font(.headline)

            let similar = findSimilarActivities()
            if similar.isEmpty {
                Text("Похожих тренировок пока не найдено.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(similar) { simActivity in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(simActivity.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(simActivity.startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                let isMetric = activeUserSettings.isMetric
                                let divisor = isMetric ? 1000.0 : 1609.344
                                let unit = isMetric ? " км" : " миль"
                                Text(String(format: "%.1f\(unit)", simActivity.distanceMeters / divisor))
                                    .font(.subheadline.weight(.medium))
                                
                                if simActivity.sportType.lowercased().contains("swim") {
                                    let simPace = (simActivity.averageSpeed ?? 0) > 0 ? (100.0 / (simActivity.averageSpeed ?? 1.0)) : 0.0
                                    Text(formattedPace(simPace) + "/100 м")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if simActivity.sportType.lowercased().contains("ride") {
                                    let speedMult = isMetric ? 3.6 : 2.23694
                                    let speedUnit = isMetric ? " км/ч" : " миль/ч"
                                    Text(String(format: "%.1f\(speedUnit)", (simActivity.averageSpeed ?? 0) * speedMult))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    let paceUnit = isMetric ? 1000.0 : 1609.344
                                    let paceLabel = isMetric ? "/км" : "/милю"
                                    let simPace = (simActivity.averageSpeed ?? 0) > 0 ? (paceUnit / (simActivity.averageSpeed ?? 1.0)) : 0.0
                                    Text(formattedPace(simPace) + paceLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var naismithEstimatedTime: TimeInterval {
        let distanceKm = activity.distanceMeters / 1000.0
        let ascentMeters = activity.elevationGain
        let hours = (distanceKm / 5.0) + (ascentMeters / 600.0)
        return hours * 3600.0 // in seconds
    }

    private var hikeStatisticsSection: some View {
        let isRussian = AppLanguage.isRussian
        let isMetric = activeUserSettings.isMetric
        let elevMultiplier = isMetric ? 1.0 : 3.28084
        let elevUnit = isMetric ? "м" : "фт"
        
        let maxAlt = activity.maxAltitude ?? (streamSamples.compactMap { $0.altitude }.max() ?? 0.0)
        let descent = activity.totalElevationLoss ?? 0.0
        
        let actualTime = activity.movingTime
        let estTime = naismithEstimatedTime
        let speedDiffPercent = estTime > 0 ? ((estTime - actualTime) / estTime) * 100 : 0.0
        
        return VStack(alignment: .leading, spacing: 14) {
            Text(isRussian ? "Анализ похода (Правило Найсмита)" : "Hike Analysis (Naismith's Rule)")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isRussian ? "Макс. высота" : "Max Altitude")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f %@", maxAlt * elevMultiplier, elevUnit))
                            .font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isRussian ? "Спуск (Потеря)" : "Total Descent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f %@", descent * elevMultiplier, elevUnit))
                            .font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(isRussian ? "Сравнение с нормой Найсмита" : "Comparison to Naismith Standard")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isRussian ? "Расчетное время" : "Estimated Time")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(formattedDuration(estTime))
                                .font(.subheadline.bold())
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(isRussian ? "Фактическое время" : "Actual Time")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(formattedDuration(actualTime))
                                .font(.subheadline.bold())
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    let diffText: String = {
                        if speedDiffPercent > 0 {
                            return isRussian ? String(format: "Вы шли на %.0f%% быстрее нормы Найсмита! 🚀", speedDiffPercent) : String(format: "You walked %.0f%% faster than Naismith rate! 🚀", speedDiffPercent)
                        } else {
                            return isRussian ? String(format: "Вы шли на %.0f%% медленнее нормы Найсмита.", abs(speedDiffPercent)) : String(format: "You walked %.0f%% slower than Naismith rate.", abs(speedDiffPercent))
                        }
                    }()
                    
                    Text(diffText)
                        .font(.caption)
                        .foregroundStyle(speedDiffPercent > 0 ? .green : .orange)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color.primary.opacity(0.02))
                .cornerRadius(12)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.03), radius: 8)
            )
        }
    }

    // MARK: - Helper Struct for Chart Plot Points
    private struct ChartDataPoint: Identifiable {
        let id = UUID()
        let x: Double
        let y: Double
    }

    // MARK: - Helper Methods & Sports Science Algorithms

    private var hasPowerStream: Bool {
        streamSamples.contains { $0.power != nil }
    }

    private var validGpsCoordinates: [CLLocationCoordinate2D] {
        streamSamples.compactMap { sample in
            if let lat = sample.latitude, let lon = sample.longitude {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            return nil
        }
    }

    private func triggerStreamFetch() {
        isLoadingStreams = true
        streamLoadingError = nil

        Task {
            do {
                let refresher = StravaTokenRefresher(config: config)
                let session = StravaSession(tokenStore: tokenStore, refresher: refresher)
                let client = StravaAPIClient(session: session)

                if let streams = try await client.streams(activityId: activity.stravaId) {
                    await MainActor.run {
                        parseAndSaveStreams(streams)
                    }
                } else {
                    await MainActor.run {
                        activity.streamsImported = true
                        isLoadingStreams = false
                    }
                }
            } catch {
                await MainActor.run {
                    streamLoadingError = "Could not download stream metrics: \(error.localizedDescription)"
                    isLoadingStreams = false
                }
            }
        }
    }

    @MainActor
    private func parseAndSaveStreams(_ streams: StravaStreamSet) {
        let size = streams.time?.count ?? 0
        guard size > 0 else {
            activity.streamsImported = true
            isLoadingStreams = false
            return
        }

        // Delete any existing samples first (to overwrite clean)
        let id = activity.stravaId
        try? modelContext.delete(model: ActivityStreamSample.self, where: #Predicate<ActivityStreamSample> { sample in
            sample.activityId == id
        })

        var samplesArray: [ActivityStreamSample] = []
        for i in 0..<size {
            let offset = streams.time?[i] ?? i
            let dist = streams.distance?[i]
            
            var lat: Double? = nil
            var lon: Double? = nil
            if let latlng = streams.latlng, i < latlng.count {
                lat = latlng[i][0]
                lon = latlng[i][1]
            }

            let hr = streams.heartrate?[i]
            let cad = streams.cadence?[i]
            let powValue = streams.watts?[i]
            let speedValue = streams.velocitySmooth?[i]
            let alt = streams.altitude?[i]

            let sample = ActivityStreamSample(
                activityId: id,
                offsetSeconds: offset,
                distanceMeters: dist,
                latitude: lat,
                longitude: lon,
                heartRate: hr,
                cadence: cad,
                power: powValue,
                speed: speedValue,
                altitude: alt
            )
            modelContext.insert(sample)
            samplesArray.append(sample)
        }

        // Calculate and cache personal records for this activity
        PersonalRecordCalculator.calculateAndSetRecords(for: activity, samples: samplesArray)
        SegmentMatcher.matchSegments(for: activity, samples: samplesArray, context: modelContext)
        PersonalSegmentMatcher.matchPersonalSegments(for: activity, samples: samplesArray, context: modelContext)

        // Delete any existing interval segments first
        try? modelContext.delete(model: IntervalSegment.self, where: #Predicate<IntervalSegment> { segment in
            segment.activityId == id
        })

        // Run the interval autodetection algorithm
        let detected = IntervalDetector.detectIntervals(
            activityId: id,
            averageSpeed: activity.averageSpeed ?? (activity.distanceMeters / (activity.movingTime > 0 ? activity.movingTime : 1.0)),
            samples: samplesArray
        )
        for seg in detected {
            modelContext.insert(seg)
        }

        activity.streamsImported = true
        isLoadingStreams = false
        try? modelContext.save()
    }

    // Downsamples route coordinates for efficient pace-gradient polyline rendering
    private func makeMapSegments(from samples: [ActivityStreamSample]) -> [MapSegment] {
        let validSamples = samples.filter { $0.latitude != nil && $0.longitude != nil }
        guard validSamples.count >= 2 else { return [] }

        // Determine downsampling factor to get ~100 segments
        let maxSegments = 100
        let strideFactor = max(1, validSamples.count / maxSegments)
        
        var segments: [MapSegment] = []
        let speeds = validSamples.compactMap { $0.speed }
        let minSpeed = speeds.min() ?? 0.1
        let maxSpeed = speeds.max() ?? 10.0
        let speedRange = max(0.1, maxSpeed - minSpeed)

        let elevations = validSamples.compactMap { $0.altitude }
        let minElev = elevations.min() ?? 0.0
        let maxElev = elevations.max() ?? 1.0
        let elevRange = max(1.0, maxElev - minElev)
        
        let isWalkOrHike = activity.sportType.lowercased().contains("walk") || activity.sportType.lowercased().contains("hike")

        var i = 0
        while i < validSamples.count - 1 {
            let nextIndex = min(i + strideFactor, validSamples.count - 1)
            let chunk = validSamples[i...nextIndex]
            
            let coords = chunk.compactMap { s in
                CLLocationCoordinate2D(latitude: s.latitude!, longitude: s.longitude!)
            }
            
            if coords.count >= 2 {
                let color: Color
                if isWalkOrHike {
                    let avgElev = chunk.compactMap { $0.altitude }.reduce(0, +) / Double(chunk.count)
                    let ratio = min(1.0, max(0.0, (avgElev - minElev) / elevRange))
                    // Color mapping: Purple (low elevation) -> Blue -> Teal -> Green (high elevation)
                    // Using HSL Hue spectrum: 0.75 (purple) to 0.35 (green)
                    let hue = 0.75 - (ratio * 0.40)
                    color = Color(hue: hue, saturation: 0.9, brightness: 0.9)
                } else {
                    let avgSpeed = chunk.compactMap { $0.speed }.reduce(0, +) / Double(chunk.count)
                    let ratio = min(1.0, max(0.0, (avgSpeed - minSpeed) / speedRange))
                    // Color mapping: Red (slow) -> Orange -> Yellow -> Green (fast)
                    // Using HSL Hue spectrum: 0.0 (red) to 0.35 (green)
                    let hue = ratio * 0.35
                    color = Color(hue: hue, saturation: 0.9, brightness: 0.9)
                }
                
                segments.append(MapSegment(coordinates: coords, color: color))
            }
            
            i = nextIndex
        }

        return segments
    }

    private func makeChartData() -> [ChartDataPoint] {
        guard !streamSamples.isEmpty else { return [] }
        
        let isMetric = activeUserSettings.isMetric
        let distDivider = isMetric ? 1000.0 : 1609.344
        let paceMultiplier = isMetric ? 1000.0 : 1609.344
        let elevMultiplier = isMetric ? 1.0 : 3.28084
        
        // Downsample charts data to ~100 points
        let step = max(1, streamSamples.count / 100)
        var points: [ChartDataPoint] = []
        
        for i in stride(from: 0, to: streamSamples.count, by: step) {
            let sample = streamSamples[i]
            let km = (sample.distanceMeters ?? Double(sample.offsetSeconds) * (activity.averageSpeed ?? 3.0)) / distDivider
            
            let yValue: Double? = {
                switch selectedChartTab {
                case .heartRate:
                    return sample.heartRate
                case .pace:
                    if activity.sportType.lowercased().contains("swim") {
                        // min/100m
                        return (sample.speed ?? 0) > 0 ? (100.0 / sample.speed!) : nil
                    } else {
                        // min/km or min/mi
                        return (sample.speed ?? 0) > 0 ? (paceMultiplier / sample.speed!) : nil
                    }
                case .elevation:
                    return sample.altitude != nil ? (sample.altitude! * elevMultiplier) : nil
                case .power:
                    return sample.power
                }
            }()
            
            if let yValue {
                points.append(ChartDataPoint(x: km, y: yValue))
            }
        }
        return points
    }

    private func chartColor(_ tab: ChartTab) -> Color {
        switch tab {
        case .heartRate: return .red
        case .pace: return .blue
        case .elevation: return .orange
        case .power: return .purple
        }
    }

    private func formatValue(_ value: Double, tab: ChartTab) -> String {
        let isMetric = activeUserSettings.isMetric
        switch tab {
        case .heartRate:
            return String(format: "%.0f уд/мин", value)
        case .pace:
            let paceLabel = activity.sportType.lowercased().contains("swim") ? " /100 м" : (isMetric ? " /км" : " /милю")
            return formattedPace(value) + paceLabel
        case .elevation:
            let elevUnit = isMetric ? " м" : " фт"
            return String(format: "%.0f\(elevUnit)", value)
        case .power:
            return String(format: "%.0f Вт", value)
        }
    }


    private func calculateKilometerSplits() -> [KilometerSplit] {
        var splits: [KilometerSplit] = []
        guard streamSamples.count >= 2 else { return [] }
        
        let isMetric = activeUserSettings.isMetric
        let splitDistanceUnit = isMetric ? 1000.0 : 1609.344
        let elevMultiplier = isMetric ? 1.0 : 3.28084
        
        var currentKm = 1
        var startIdx = 0
        
        while startIdx < streamSamples.count {
            let targetDistance = Double(currentKm) * splitDistanceUnit
            var endIdx = startIdx
            
            // Find index matching targetDistance
            while endIdx < streamSamples.count && (streamSamples[endIdx].distanceMeters ?? 0) < targetDistance {
                endIdx += 1
            }
            
            if endIdx >= streamSamples.count {
                // Handle remaining fraction if > 200m
                if endIdx > startIdx + 5 {
                    let lastSample = streamSamples.last!
                    let startSample = streamSamples[startIdx]
                    let distDiff = (lastSample.distanceMeters ?? 0) - (startSample.distanceMeters ?? 0)
                    
                    if distDiff >= 200 {
                        let timeDiff = TimeInterval(lastSample.offsetSeconds - startSample.offsetSeconds)
                        let pace = distDiff > 0 ? (timeDiff / (distDiff / splitDistanceUnit)) : 0
                        
                        let chunk = streamSamples[startIdx..<streamSamples.count]
                        let hrSum = chunk.compactMap { $0.heartRate }
                        let avgHR = hrSum.isEmpty ? nil : hrSum.reduce(0, +) / Double(hrSum.count)
                        let elevChange = ((lastSample.altitude ?? 0) - (startSample.altitude ?? 0)) * elevMultiplier
                        
                        splits.append(KilometerSplit(
                            index: currentKm,
                            pace: pace,
                            avgHeartRate: avgHR,
                            elevationChange: elevChange
                        ))
                    }
                }
                break
            }
            
            let startSample = streamSamples[startIdx]
            let endSample = streamSamples[endIdx]
            
            let distDiff = (endSample.distanceMeters ?? 0) - (startSample.distanceMeters ?? 0)
            let timeDiff = TimeInterval(endSample.offsetSeconds - startSample.offsetSeconds)
            let pace = distDiff > 0 ? (timeDiff / (distDiff / splitDistanceUnit)) : 0
            
            let chunk = streamSamples[startIdx...endIdx]
            let hrSum = chunk.compactMap { $0.heartRate }
            let avgHR = hrSum.isEmpty ? nil : hrSum.reduce(0, +) / Double(hrSum.count)
            let elevChange = ((endSample.altitude ?? 0) - (startSample.altitude ?? 0)) * elevMultiplier
            
            splits.append(KilometerSplit(
                index: currentKm,
                pace: pace,
                avgHeartRate: avgHR,
                elevationChange: elevChange
            ))
            
            currentKm += 1
            startIdx = endIdx + 1
        }
        
        return splits
    }

    private func calculateHeartRateZoneTimes(maxHR: Double) -> [Int] {
        var zoneTimes = [0, 0, 0, 0, 0]
        guard streamSamples.count >= 2 else { return zoneTimes }
        
        let zones = activeUserSettings.effectiveHeartRateZones(maxHR: maxHR) // returns [Z1Max, Z2Max, Z3Max, Z4Max]
        let restingHR = activeUserSettings.restingHeartRate
        
        for i in 1..<streamSamples.count {
            let prev = streamSamples[i-1]
            let curr = streamSamples[i]
            let duration = curr.offsetSeconds - prev.offsetSeconds
            
            guard duration > 0, let hr = curr.heartRate else { continue }
            
            if hr > zones[3] {
                zoneTimes[4] += duration // Zone 5
            } else if hr > zones[2] {
                zoneTimes[3] += duration // Zone 4
            } else if hr > zones[1] {
                zoneTimes[2] += duration // Zone 3
            } else if hr > zones[0] {
                zoneTimes[1] += duration // Zone 2
            } else if Double(hr) >= restingHR {
                zoneTimes[0] += duration // Zone 1
            }
        }
        
        return zoneTimes
    }

    private func zoneColor(_ index: Int) -> Color {
        switch index {
        case 0: return .blue
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        default: return .secondary
        }
    }

    private func zoneBpmRange(_ index: Int, maxHR: Double) -> String {
        let zones = activeUserSettings.effectiveHeartRateZones(maxHR: maxHR)
        switch index {
        case 0: return String(format: "Активное восстановление: %.0f-%.0f уд/мин", activeUserSettings.restingHeartRate, zones[0])
        case 1: return String(format: "Аэробная выносливость: %.0f-%.0f уд/мин", zones[0], zones[1])
        case 2: return String(format: "Темповая зона: %.0f-%.0f уд/мин", zones[1], zones[2])
        case 3: return String(format: "Лактатный порог: %.0f-%.0f уд/мин", zones[2], zones[3])
        case 4: return String(format: "Анаэробная зона: >%.0f уд/мин", zones[3])
        default: return ""
        }
    }

    private func calculateNormalizedPower(from stream: [Double]) -> Double? {
        guard stream.count >= 30 else { return nil }
        var powersOfRollingAvgs: [Double] = []
        
        for i in 29..<stream.count {
            let sum = stream[(i-29)...i].reduce(0, +)
            let avg = sum / 30.0
            powersOfRollingAvgs.append(pow(avg, 4))
        }
        
        guard !powersOfRollingAvgs.isEmpty else { return nil }
        let meanOfPowers = powersOfRollingAvgs.reduce(0, +) / Double(powersOfRollingAvgs.count)
        return pow(meanOfPowers, 0.25)
    }

    private func calculateTSS(duration: TimeInterval, np: Double?, ftp: Double = 250.0) -> Double? {
        guard let np else { return nil }
        // TSS = (sec * NP * IF) / (FTP * 3600) * 100
        // IF = NP / FTP
        let intensityFactor = np / ftp
        let tss = (duration * np * intensityFactor) / (ftp * 3600.0) * 100.0
        return tss
    }

    private func calculateCTLATLDeltas() -> (ctl: Double, atl: Double) {
        // Find previous chronological CTL and ATL
        let chronologicallyOrdered = allActivities.sorted { $0.startDate < $1.startDate }
        guard let currentIndex = chronologicallyOrdered.firstIndex(where: { $0.stravaId == activity.stravaId }) else {
            return (0.0, 0.0)
        }
        
        // Calculate performance management values over history
        let fitnessPoints = TrainingLoadCalculator.performanceManagement(
            loads: chronologicallyOrdered.map { ($0.startDate, $0.trainingLoad) }
        )
        
        if currentIndex < fitnessPoints.count {
            let after = fitnessPoints[currentIndex]
            let before = currentIndex > 0 ? fitnessPoints[currentIndex - 1] : FitnessPoint(date: .distantPast, ctl: 0, atl: 0, tsb: 0)
            
            return (after.ctl - before.ctl, after.atl - before.atl)
        }
        
        return (0.0, 0.0)
    }

    private func findSimilarActivities() -> [Activity] {
        let currentDist = activity.distanceMeters
        let lowerBound = currentDist * 0.8
        let upperBound = currentDist * 1.2
        let currentSport = activity.sportType
        let currentId = activity.stravaId
        
        let similar = allActivities.filter { sim in
            sim.stravaId != currentId &&
            sim.sportType == currentSport &&
            sim.distanceMeters >= lowerBound &&
            sim.distanceMeters <= upperBound &&
            sim.startDate < activity.startDate
        }
        
        // Sort similar by date descending and take top 3
        return Array(similar.sorted { $0.startDate > $1.startDate }.prefix(3))
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }

    private func formattedPace(_ seconds: Double) -> String {
        guard seconds > 0 && seconds < 3600 else { return "--:--" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func sportIconName(_ sportType: String) -> String {
        let lower = sportType.lowercased()
        if lower.contains("run") { return "figure.run" }
        if lower.contains("ride") || lower.contains("cycle") { return "figure.outdoor.cycle" }
        if lower.contains("swim") { return "figure.pool.swim" }
        return "figure.mixed.cardio"
    }

    private var intervalAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Анализ интервалов")
                    .font(.headline)
                Spacer()
                
                if let _ = similarPreviousActivity {
                    Button {
                        isShowingComparison = true
                    } label: {
                        Label("Сравнить", systemImage: "arrow.left.and.right")
                            .font(.caption).fontWeight(.bold)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }
            
            let workReps = activitySegments.filter { $0.type == "work" }
            let isRussian = AppLanguage.isRussian
            
            // Best & Worst work repeats
            let bestRep = workReps.max(by: { $0.averageSpeed < $1.averageSpeed }) // highest speed is best
            let worstRep = workReps.min(by: { $0.averageSpeed < $1.averageSpeed }) // lowest speed is worst
            
            // Metrics card: pace degradation
            HStack(spacing: 12) {
                if let bestRep {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Лучший повтор").font(.caption).foregroundStyle(.secondary)
                        Text(formattedPace(1000.0 / bestRep.averageSpeed) + "/км")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                
                if let worstRep {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Худший повтор").font(.caption).foregroundStyle(.secondary)
                        Text(formattedPace(1000.0 / worstRep.averageSpeed) + "/км")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                
                // Pace degradation (percent change from first rep to last rep)
                if workReps.count >= 2, let first = workReps.first, let last = workReps.last {
                    let firstPace = 1000.0 / first.averageSpeed
                    let lastPace = 1000.0 / last.averageSpeed
                    let degradation = ((lastPace - firstPace) / firstPace) * 100.0
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Дрифт темпа").font(.caption).foregroundStyle(.secondary)
                        Text(String(format: "%+.1f%%", degradation))
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(degradation > 5.0 ? .red : .blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // Pace Degradation Line Chart
            if workReps.count >= 3 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Деградация темпа серии")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    if NSClassFromString("XCTestCase") == nil {
                        Chart {
                            ForEach(workReps) { rep in
                                LineMark(
                                    x: .value("Повтор", "№\(rep.segmentIndex / 2 + 1)"),
                                    y: .value("Темп (сек)", 1000.0 / rep.averageSpeed)
                                )
                                .foregroundStyle(.blue.gradient)
                                .symbol(Circle())
                                .accessibilityLabel(isRussian ? "Деградация темпа серии" : "Pace Degradation")
                                .accessibilityValue(String(format: isRussian ? "Повтор №%d, темп: %@" : "Repeat #%d, pace: %@", rep.segmentIndex / 2 + 1, formattedPace(1000.0 / rep.averageSpeed)))
                            }
                        }
                        .frame(height: 100)
                        .chartYAxis {
                            AxisMarks { value in
                                if let seconds = value.as(Double.self) {
                                    AxisValueLabel(formattedPace(seconds))
                                }
                            }
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 100)
                            .overlay(
                                Text("График деградации темпа")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .padding(10)
                .background(Color.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
            
            // Repeats Table
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Повтор").frame(width: 70, alignment: .leading)
                    Text("Дист.").frame(width: 60, alignment: .trailing)
                    Text("Время").frame(width: 60, alignment: .trailing)
                    Text("Темп").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Пульс").frame(width: 50, alignment: .trailing)
                }
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
                .padding(.horizontal, 10)
                
                ForEach(workReps) { rep in
                    let repNumber = rep.segmentIndex / 2 + 1
                    
                    HStack {
                        Text("Повтор \(repNumber)")
                            .font(.subheadline).fontWeight(.semibold)
                            .frame(width: 70, alignment: .leading)
                        
                        Text(String(format: "%.0fm", rep.endDistanceMeters - rep.startDistanceMeters))
                            .frame(width: 60, alignment: .trailing)
                        
                        Text(formattedDuration(rep.duration))
                            .frame(width: 60, alignment: .trailing)
                        
                        Text(formattedPace(1000.0 / rep.averageSpeed) + "/км")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundStyle(rep.segmentIndex == bestRep?.segmentIndex ? .green : (rep.segmentIndex == worstRep?.segmentIndex ? .red : .primary))
                        
                        Text(rep.averageHeartRate != nil ? String(format: "%.0f", rep.averageHeartRate!) : "--")
                            .frame(width: 50, alignment: .trailing)
                    }
                    .font(.caption)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(rep.segmentIndex == bestRep?.segmentIndex ? Color.green.opacity(0.05) : (rep.segmentIndex == worstRep?.segmentIndex ? Color.red.opacity(0.05) : Color.clear))
                    
                    Divider()
                }
            }
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var similarPreviousActivity: Activity? {
        let sortedOther = allActivities
            .filter { $0.stravaId != activity.stravaId && $0.sportType == activity.sportType && $0.startDate < activity.startDate }
            .sorted { $0.startDate > $1.startDate } // newest first
        
        for other in sortedOther {
            let otherId = other.stravaId
            let count = allSegments.filter { $0.activityId == otherId && $0.type == "work" }.count
            let currentWorkCount = activitySegments.filter { $0.type == "work" }.count
            if count >= 3 && abs(count - currentWorkCount) <= 2 {
                return other
            }
        }
        return nil
    }
    
    private var comparisonSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let prev = similarPreviousActivity {
                        let currentWork = activitySegments.filter { $0.type == "work" }
                        let prevSegs = allSegments.filter { $0.activityId == prev.stravaId && $0.type == "work" }.sorted { $0.segmentIndex < $1.segmentIndex }
                        
                        Text("Сравнение с предыдущей сессией")
                            .font(.title3).fontWeight(.bold)
                            .padding(.top)
                        
                        Text("Предыдущий аналогичный старт: \(prev.startDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        // Summary Side-by-Side metrics card
                        VStack(spacing: 12) {
                            HStack {
                                Text("Метрика").bold().frame(maxWidth: .infinity, alignment: .leading)
                                Text("Ранее").bold().frame(width: 80, alignment: .trailing)
                                Text("Сейчас").bold().frame(width: 80, alignment: .trailing)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            
                            Divider()
                            
                            let currentAvgSpeed = currentWork.reduce(0.0) { $0 + $1.averageSpeed } / Double(currentWork.count)
                            let prevAvgSpeed = prevSegs.reduce(0.0) { $0 + $1.averageSpeed } / Double(prevSegs.count)
                            
                            comparisonRow(
                                title: "Средний темп повтора",
                                prevVal: formattedPace(1000.0 / prevAvgSpeed) + "/км",
                                currentVal: formattedPace(1000.0 / currentAvgSpeed) + "/км",
                                better: currentAvgSpeed > prevAvgSpeed
                            )
                            
                            let currentAvgHR = currentWork.compactMap { $0.averageHeartRate }.reduce(0.0, +) / Double(max(1, currentWork.compactMap { $0.averageHeartRate }.count))
                            let prevAvgHR = prevSegs.compactMap { $0.averageHeartRate }.reduce(0.0, +) / Double(max(1, prevSegs.compactMap { $0.averageHeartRate }.count))
                            
                            if currentAvgHR > 0 && prevAvgHR > 0 {
                                comparisonRow(
                                    title: "Средний пульс работы",
                                    prevVal: String(format: "%.0f уд/мин", prevAvgHR),
                                    currentVal: String(format: "%.0f уд/мин", currentAvgHR),
                                    better: currentAvgHR < prevAvgHR
                                )
                            }
                            
                            let currentAvgPow = currentWork.compactMap { $0.averagePower }.reduce(0.0, +) / Double(max(1, currentWork.compactMap { $0.averagePower }.count))
                            let prevAvgPow = prevSegs.compactMap { $0.averagePower }.reduce(0.0, +) / Double(max(1, prevSegs.compactMap { $0.averagePower }.count))
                            
                            if currentAvgPow > 0 && prevAvgPow > 0 {
                                comparisonRow(
                                    title: "Средняя мощность работы",
                                    prevVal: String(format: "%.0f Вт", prevAvgPow),
                                    currentVal: String(format: "%.0f Вт", currentAvgPow),
                                    better: currentAvgPow > prevAvgPow
                                )
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        
                        // Repeats details side by side
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Сравнение по интервалам:")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                ForEach(0..<max(currentWork.count, prevSegs.count), id: \.self) { idx in
                                    HStack {
                                        Text("Интервал \(idx + 1)")
                                            .font(.subheadline).fontWeight(.semibold)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        if idx < prevSegs.count {
                                            Text(formattedPace(1000.0 / prevSegs[idx].averageSpeed))
                                                .frame(width: 80, alignment: .trailing)
                                        } else {
                                            Text("--:--").frame(width: 80, alignment: .trailing)
                                        }
                                        
                                        if idx < currentWork.count {
                                            let better = idx < prevSegs.count ? (currentWork[idx].averageSpeed > prevSegs[idx].averageSpeed) : true
                                            Text(formattedPace(1000.0 / currentWork[idx].averageSpeed))
                                                .frame(width: 80, alignment: .trailing)
                                                .foregroundStyle(better ? .green : .red)
                                        } else {
                                            Text("--:--").frame(width: 80, alignment: .trailing)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                    
                                    Divider()
                                }
                            }
                            .background(Color.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") {
                        isShowingComparison = false
                    }
                }
            }
        }
    }
    
    private func comparisonRow(title: String, prevVal: String, currentVal: String, better: Bool) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            Text(prevVal).font(.subheadline).frame(width: 80, alignment: .trailing)
            Text(currentVal).font(.subheadline).fontWeight(.bold)
                .foregroundStyle(better ? .green : .red)
                .frame(width: 80, alignment: .trailing)
        }
    }
    
    private func triggerGPXExport() {
        let xml = ExportManager.exportToGPX(activity: activity, samples: streamSamples)
        let filename = "activity_\(activity.stravaId).gpx"
        saveAndShare(content: xml, filename: filename)
    }
    
    private func triggerCSVExport() {
        let csv = ExportManager.exportStreamToCSV(activity: activity, samples: streamSamples)
        let filename = "activity_\(activity.stravaId)_stream.csv"
        saveAndShare(content: csv, filename: filename)
    }
    
    private func saveAndShare(content: String, filename: String) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            self.shareURL = fileURL
            self.isShowingShareSheet = true
        } catch {
            print("Failed to write temporary export file: \(error)")
        }
    }

    // MARK: - Section 10: Power Curve Helpers & Views

    private var hasPowerCurveData: Bool {
        activity.peakPower1s != nil && activity.peakPower1s! > 0
    }

    @ViewBuilder
    private var activityPowerCurveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Кривая мощности тренировки")
                    .font(.headline)
                Spacer()
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
            }
            
            // Build data points
            let curvePoints = buildActivityAndRecordCurvePoints()
            
            PowerCurveChartView(
                points: curvePoints,
                useRelative: false, // Default absolute Watts for workout detail
                selectedPoint: $selectedPowerPoint
            )
            
            // Highlight selected point info if interactive
            if let selected = selectedPowerPoint {
                HStack {
                    Text("\(selected.durationLabel):")
                        .font(.subheadline.weight(.semibold))
                    Text("\(Int(selected.watts)) Вт")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.blue)
                    Spacer()
                    Text(selected.type)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(selected.type == "Рекорд" ? Color.blue.opacity(0.12) : Color.orange.opacity(0.12))
                        .cornerRadius(4)
                }
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            
            // Highlight record achievements (Best efforts on this activity)
            let records = checkNewRecords()
            if !records.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Рекорды в этой тренировке:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                    ForEach(records, id: \.self) { recordMsg in
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(recordMsg)
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func buildActivityAndRecordCurvePoints() -> [PowerPoint] {
        let weight = activeUserSettings.weightKg > 0 ? activeUserSettings.weightKg : 70.0
        var points: [PowerPoint] = []
        
        func addPoints(duration: Int, label: String, actVal: Double?, recordVal: Double) {
            if let act = actVal, act > 0 {
                points.append(PowerPoint(
                    duration: duration,
                    durationLabel: label,
                    watts: act,
                    relativeWatts: act / weight,
                    type: "Тренировка",
                    date: activity.startDate
                ))
            }
            if recordVal > 0 {
                points.append(PowerPoint(
                    duration: duration,
                    durationLabel: label,
                    watts: recordVal,
                    relativeWatts: recordVal / weight,
                    type: "Рекорд",
                    date: nil
                ))
            }
        }
        
        let all = allActivities
        addPoints(duration: 1, label: "1с", actVal: activity.peakPower1s, recordVal: all.compactMap { $0.peakPower1s }.max() ?? 0)
        addPoints(duration: 5, label: "5с", actVal: activity.peakPower5s, recordVal: all.compactMap { $0.peakPower5s }.max() ?? 0)
        addPoints(duration: 15, label: "15с", actVal: activity.peakPower15s, recordVal: all.compactMap { $0.peakPower15s }.max() ?? 0)
        addPoints(duration: 30, label: "30с", actVal: activity.peakPower30s, recordVal: all.compactMap { $0.peakPower30s }.max() ?? 0)
        addPoints(duration: 60, label: "1м", actVal: activity.peakPower1m, recordVal: all.compactMap { $0.peakPower1m }.max() ?? 0)
        addPoints(duration: 120, label: "2м", actVal: activity.peakPower2m, recordVal: all.compactMap { $0.peakPower2m }.max() ?? 0)
        addPoints(duration: 300, label: "5м", actVal: activity.peakPower5m, recordVal: all.compactMap { $0.peakPower5m }.max() ?? 0)
        addPoints(duration: 600, label: "10m", actVal: activity.peakPower10m, recordVal: all.compactMap { $0.peakPower10m }.max() ?? 0)
        addPoints(duration: 1200, label: "20m", actVal: activity.peakPower20m, recordVal: all.compactMap { $0.peakPower20m }.max() ?? 0)
        addPoints(duration: 3600, label: "1ч", actVal: activity.peakPower60m, recordVal: all.compactMap { $0.peakPower60m }.max() ?? 0)
        
        return points
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

    private func checkNewRecords() -> [String] {
        var records: [String] = []
        let otherActivities = allActivities.filter { $0.stravaId != activity.stravaId }
        
        func check(duration: String, val: Double?, maxOther: Double?) {
            if let v = val, v > 0, v >= (maxOther ?? 0) {
                records.append("Личный рекорд мощности на \(duration): \(Int(v)) Вт!")
            }
        }
        
        check(duration: "1 секунду", val: activity.peakPower1s, maxOther: otherActivities.compactMap { $0.peakPower1s }.max())
        check(duration: "5 секунд", val: activity.peakPower5s, maxOther: otherActivities.compactMap { $0.peakPower5s }.max())
        check(duration: "15 секунд", val: activity.peakPower15s, maxOther: otherActivities.compactMap { $0.peakPower15s }.max())
        check(duration: "30 секунд", val: activity.peakPower30s, maxOther: otherActivities.compactMap { $0.peakPower30s }.max())
        check(duration: "1 минуту", val: activity.peakPower1m, maxOther: otherActivities.compactMap { $0.peakPower1m }.max())
        check(duration: "2 минуты", val: activity.peakPower2m, maxOther: otherActivities.compactMap { $0.peakPower2m }.max())
        check(duration: "5 минут", val: activity.peakPower5m, maxOther: otherActivities.compactMap { $0.peakPower5m }.max())
        check(duration: "10 минут", val: activity.peakPower10m, maxOther: otherActivities.compactMap { $0.peakPower10m }.max())
        check(duration: "20 минут", val: activity.peakPower20m, maxOther: otherActivities.compactMap { $0.peakPower20m }.max())
        check(duration: "1 час", val: activity.peakPower60m, maxOther: otherActivities.compactMap { $0.peakPower60m }.max())
        
        return records
    }

    private var matchedSegmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Пройденные сегменты")
                .font(.headline)
                .foregroundColor(.primary)
            
            if matchedSegmentEfforts.isEmpty {
                Text("На этой тренировке не обнаружено пересечений с популярными сегментами.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(matchedSegmentEfforts) { effort in
                        if let seg = effort.segment {
                            NavigationLink(destination: SegmentDetailView(segment: seg)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(seg.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 8) {
                                            Text(String(format: "%.1f%% уклон", seg.averageGrade))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            
                                            Text(formatDistance(seg.distanceMeters))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if isPersonalRecord(effort) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "crown.fill")
                                                .font(.caption)
                                                .foregroundColor(.yellow)
                                            Text("ЛР")
                                                .font(.caption2.weight(.bold))
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.yellow.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(formatDuration(effort.elapsedTime))
                                            .font(.subheadline.weight(.bold))
                                            .foregroundColor(.primary)
                                        
                                        if let hr = effort.averageHeartRate {
                                            Text(String(format: "❤️ %.0f уд/мин", hr))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }

    private func isPersonalRecord(_ effort: SegmentEffort) -> Bool {
        guard let seg = effort.segment else { return false }
        let userEfforts = seg.efforts.filter { !$0.isMock && $0.athleteName == "Вы" }
        guard let bestTime = userEfforts.map({ $0.elapsedTime }).min() else { return false }
        return effort.elapsedTime <= bestTime
    }

    private func formatDistance(_ meters: Double) -> String {
        let isMetric = activeUserSettings.isMetric
        if isMetric {
            if meters >= 1000 {
                return String(format: "%.2f км", meters / 1000.0)
            } else {
                return "\(Int(meters)) м"
            }
        } else {
            let miles = meters / 1609.344
            if miles >= 0.1 {
                return String(format: "%.2f миль", miles)
            } else {
                let feet = meters * 3.28084
                return "\(Int(feet)) футов"
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Running Dynamics Helpers & Views
    
    private var selectedDynamicsSample: ActivityStreamSample? {
        guard let dist = selectedDynamicsDistance, !streamSamples.isEmpty else { return nil }
        let isMetric = activeUserSettings.isMetric
        let distDivider = isMetric ? 1000.0 : 1609.344
        return streamSamples.min(by: {
            let d1 = abs((($0.distanceMeters ?? Double($0.offsetSeconds) * (activity.averageSpeed ?? 3.0)) / distDivider) - dist)
            let d2 = abs((($1.distanceMeters ?? Double($1.offsetSeconds) * (activity.averageSpeed ?? 3.0)) / distDivider) - dist)
            return d1 < d2
        })
    }
    
    private func makeDynamicsChartData() -> (osc: [ChartDataPoint], gct: [ChartDataPoint], stride: [ChartDataPoint], cadence: [ChartDataPoint]) {
        guard !streamSamples.isEmpty else { return ([], [], [], []) }
        
        let isMetric = activeUserSettings.isMetric
        let distDivider = isMetric ? 1000.0 : 1609.344
        let strideMultiplier = isMetric ? 1.0 : 3.28084
        
        let step = max(1, streamSamples.count / 100)
        
        var oscPoints: [ChartDataPoint] = []
        var gctPoints: [ChartDataPoint] = []
        var stridePoints: [ChartDataPoint] = []
        var cadencePoints: [ChartDataPoint] = []
        
        for i in stride(from: 0, to: streamSamples.count, by: step) {
            let sample = streamSamples[i]
            let km = (sample.distanceMeters ?? Double(sample.offsetSeconds) * (activity.averageSpeed ?? 3.0)) / distDivider
            
            if let osc = sample.verticalOscillation {
                oscPoints.append(ChartDataPoint(x: km, y: osc))
            }
            if let gct = sample.groundContactTime {
                gctPoints.append(ChartDataPoint(x: km, y: gct))
            }
            if let stride = sample.strideLength {
                stridePoints.append(ChartDataPoint(x: km, y: stride * strideMultiplier))
            }
            if let cad = sample.cadence {
                cadencePoints.append(ChartDataPoint(x: km, y: cad))
            }
        }
        
        return (oscPoints, gctPoints, stridePoints, cadencePoints)
    }
    
    private var dynamicsChartHeaderView: some View {
        let isRussian = AppLanguage.isRussian
        let isMetric = activeUserSettings.isMetric
        let strideMultiplier = isMetric ? 1.0 : 3.28084
        let strideUnit = isMetric ? "м" : "фт"
        
        return HStack {
            if let selected = selectedDynamicsSample {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isRussian ? "ДЕТАЛИ ТОЧКИ" : "POINT DETAILS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    
                    let distValue = (selected.distanceMeters ?? Double(selected.offsetSeconds) * (activity.averageSpeed ?? 3.0)) / (isMetric ? 1000.0 : 1609.344)
                    Text(String(format: isRussian ? "Дистанция: %.2f км" : "Distance: %.2f mi", distValue))
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                switch selectedDynamicsTab {
                case 0:
                    if let osc = selected.verticalOscillation {
                        let zone = RunningDynamicsEngine.classifyVerticalOscillation(osc)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(isRussian ? "ВЕРТ. КОЛЕБАНИЯ" : "VERT. OSCILLATION")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(String(format: "%.1f см", osc))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text(localizedZoneText(zone, isRussian: isRussian))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(zoneColor(zone))
                            }
                        }
                    }
                case 1:
                    if let gct = selected.groundContactTime {
                        let zone = RunningDynamicsEngine.classifyGCT(gct)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(isRussian ? "КОНТАКТ С ЗЕМЛЕЙ" : "GROUND CONTACT TIME")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(String(format: "%.0f мс", gct))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text(localizedZoneText(zone, isRussian: isRussian))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(zoneColor(zone))
                            }
                        }
                    }
                case 2:
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(isRussian ? "ДЛИНА / КАДЕНС" : "STRIDE / CADENCE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            if let stride = selected.strideLength {
                                Text(String(format: "%.2f \(strideUnit)", stride * strideMultiplier))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            if let cad = selected.cadence {
                                let zone = RunningDynamicsEngine.classifyCadence(cad)
                                HStack(spacing: 2) {
                                    Text(String(format: "%.0f шаг/мин", cad))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Circle()
                                        .fill(zoneColor(zone))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }
                default:
                    EmptyView()
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isRussian ? "СРЕДНИЕ ПОКАЗАТЕЛИ" : "AVERAGE METRICS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Text(isRussian ? "За всю тренировку" : "Entire session")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                switch selectedDynamicsTab {
                case 0:
                    if let osc = activity.averageVerticalOscillation {
                        let zone = RunningDynamicsEngine.classifyVerticalOscillation(osc)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(isRussian ? "ВЕРТ. КОЛЕБАНИЯ" : "VERT. OSCILLATION")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(String(format: "%.1f см", osc))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text(localizedZoneText(zone, isRussian: isRussian))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(zoneColor(zone))
                            }
                        }
                    }
                case 1:
                    if let gct = activity.averageGroundContactTime {
                        let zone = RunningDynamicsEngine.classifyGCT(gct)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(isRussian ? "КОНТАКТ С ЗЕМЛЕЙ" : "GROUND CONTACT TIME")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(String(format: "%.0f мс", gct))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text(localizedZoneText(zone, isRussian: isRussian))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(zoneColor(zone))
                            }
                        }
                    }
                case 2:
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(isRussian ? "ДЛИНА / КАДЕНС" : "STRIDE / CADENCE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            if let stride = activity.averageStrideLength {
                                Text(String(format: "%.2f \(strideUnit)", stride * strideMultiplier))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            if let cad = activity.averageCadence {
                                let zone = RunningDynamicsEngine.classifyCadence(cad)
                                HStack(spacing: 2) {
                                    Text(String(format: "%.0f шаг/мин", cad))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Circle()
                                        .fill(zoneColor(zone))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }
                default:
                    EmptyView()
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func localizedZoneText(_ zone: DynamicsZone, isRussian: Bool) -> String {
        if isRussian {
            switch zone {
            case .optimal: return "Отлично"
            case .good: return "Хорошо"
            case .fair: return "Удовл."
            case .poor: return "Низкий"
            }
        } else {
            switch zone {
            case .optimal: return "Optimal"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            }
        }
    }
    
    private func zoneColor(_ zone: DynamicsZone) -> Color {
        switch zone {
        case .optimal: return .purple
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    private var runningDynamicsSection: some View {
        let isRussian = AppLanguage.isRussian
        let isMetric = activeUserSettings.isMetric
        
        let avgOsc = activity.averageVerticalOscillation ?? 8.5
        let avgGCT = activity.averageGroundContactTime ?? 240.0
        let avgStride = activity.averageStrideLength ?? 1.0
        let avgBalance = activity.averageLeftGCTPercent ?? 50.0
        let avgCadenceVal = activity.averageCadence ?? 170.0
        
        let strideMultiplier = isMetric ? 1.0 : 3.28084
        let strideUnit = isMetric ? "м" : "фт"
        
        let (oscPoints, gctPoints, stridePoints, cadencePoints) = makeDynamicsChartData()
        let chartXLabel = isMetric ? "Дистанция (км)" : "Дистанция (мили)"
        let chartXUnit = isMetric ? "%.1f км" : "%.1f мили"
        
        return VStack(alignment: .leading, spacing: 16) {
            Text(isRussian ? "Беговая динамика" : "Running Dynamics")
                .font(.headline)
                .padding(.top, 8)
            
            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
            
            LazyVGrid(columns: columns, spacing: 12) {
                let cadZone = RunningDynamicsEngine.classifyCadence(avgCadenceVal)
                DynamicsGridTile(
                    title: isRussian ? "Каденс" : "Cadence",
                    value: String(format: "%.0f шаг/мин", avgCadenceVal),
                    zone: cadZone,
                    scoreText: localizedZoneText(cadZone, isRussian: isRussian),
                    percent: (avgCadenceVal - 120.0) / (200.0 - 120.0),
                    color: zoneColor(cadZone)
                )
                
                let oscZone = RunningDynamicsEngine.classifyVerticalOscillation(avgOsc)
                DynamicsGridTile(
                    title: isRussian ? "Колебания" : "Oscillation",
                    value: String(format: "%.1f см", avgOsc),
                    zone: oscZone,
                    scoreText: localizedZoneText(oscZone, isRussian: isRussian),
                    percent: max(0.0, min(1.0, (15.0 - avgOsc) / (15.0 - 4.0))),
                    color: zoneColor(oscZone)
                )
                
                let gctZone = RunningDynamicsEngine.classifyGCT(avgGCT)
                DynamicsGridTile(
                    title: isRussian ? "Контакт" : "Contact Time",
                    value: String(format: "%.0f мс", avgGCT),
                    zone: gctZone,
                    scoreText: localizedZoneText(gctZone, isRussian: isRussian),
                    percent: max(0.0, min(1.0, (350.0 - avgGCT) / (350.0 - 150.0))),
                    color: zoneColor(gctZone)
                )
                
                let strideZone = RunningDynamicsEngine.classifyStrideLength(avgStride)
                DynamicsGridTile(
                    title: isRussian ? "Длина шага" : "Stride Length",
                    value: String(format: "%.2f \(strideUnit)", avgStride * strideMultiplier),
                    zone: strideZone,
                    scoreText: localizedZoneText(strideZone, isRussian: isRussian),
                    percent: max(0.0, min(1.0, (avgStride - 0.5) / (2.0 - 0.5))),
                    color: zoneColor(strideZone)
                )
            }
            
            let balanceZone = RunningDynamicsEngine.classifyLRBalance(avgBalance)
            LRBalanceBarometer(
                leftPercent: avgBalance,
                zone: balanceZone,
                isRussian: isRussian
            )
            
            // Running Efficiency & 30-Day Averages Comparison
            let currentSpeed = activity.averageSpeed ?? 0.0
            let runningEfficiency = (avgOsc > 0 && avgCadenceVal > 0) ? (currentSpeed / (avgCadenceVal * avgOsc)) * 10000.0 : 0.0
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isRussian ? "Эффективность бега" : "Running Efficiency")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    Text(String(format: "%.2f", runningEfficiency))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.purple)
                    
                    Text(isRussian ? "Индекс (скорость / (каденс × колебания))" : "Index (speed / (cadence × osc))")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                if let averages = last30DaysRunningDynamicsAvg {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isRussian ? "Сравнение с 30-дн. средним" : "Vs 30-Day Average")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        let cadDiff = avgCadenceVal - averages.cadence
                        let strideDiff = avgStride - averages.stride
                        let oscDiff = avgOsc - averages.osc
                        let gctDiff = avgGCT - averages.gct
                        
                        VStack(alignment: .leading, spacing: 2) {
                            diffText(label: isRussian ? "Каденс" : "Cad", diff: cadDiff, format: "%+.0f шаг/мин", inverseColor: false)
                            diffText(label: isRussian ? "Шаг" : "Stride", diff: strideDiff * strideMultiplier, format: "%+.2f \(strideUnit)", inverseColor: false)
                            diffText(label: isRussian ? "Колебания" : "Osc", diff: oscDiff, format: "%+.1f см", inverseColor: true)
                            diffText(label: isRussian ? "Контакт" : "Contact", diff: gctDiff, format: "%+.0f мс", inverseColor: true)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Picker("График беговой динамики", selection: $selectedDynamicsTab) {
                    Text(isRussian ? "Колебания" : "Oscillation").tag(0)
                    Text(isRussian ? "Контакт" : "Contact").tag(1)
                    Text(isRussian ? "Шаг / Каденс" : "Stride / Cadence").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 4)
                
                dynamicsChartHeaderView
                
                if oscPoints.isEmpty {
                    Text(isRussian ? "Нет данных для построения графиков динамики." : "No data points available for dynamics charts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(height: 160)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    if NSClassFromString("XCTestCase") == nil {
                        Group {
                            switch selectedDynamicsTab {
                        case 0:
                            Chart {
                                ForEach(oscPoints) { pt in
                                    LineMark(
                                        x: .value(chartXLabel, pt.x),
                                        y: .value("Oscillation", pt.y)
                                    )
                                    .foregroundStyle(Color.purple)
                                    .interpolationMethod(.catmullRom)
                                    .accessibilityLabel(isRussian ? "Вертикальные колебания" : "Vertical Oscillation")
                                    .accessibilityValue(String(format: isRussian ? "%.1f см на расстоянии %.2f \(isMetric ? "км" : "миль")" : "%.1f cm at distance %.2f \(isMetric ? "km" : "mi")", pt.y, pt.x))
                                    
                                    AreaMark(
                                        x: .value(chartXLabel, pt.x),
                                        y: .value("Oscillation", pt.y)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.15), Color.clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)
                                }
                                
                                if let selectedDist = selectedDynamicsDistance {
                                    RuleMark(x: .value("Selected", selectedDist))
                                        .foregroundStyle(.secondary.opacity(0.5))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    
                                    if let sample = selectedDynamicsSample, let osc = sample.verticalOscillation {
                                        PointMark(
                                            x: .value("Selected", selectedDist),
                                            y: .value("Oscillation", osc)
                                        )
                                        .foregroundStyle(Color.purple)
                                        .symbol(Circle())
                                        .symbolSize(80)
                                    }
                                }
                            }
                            .frame(height: 160)
                            .chartXSelection(value: $selectedDynamicsDistance)
                            .chartXAxis {
                                AxisMarks(values: .automatic) { value in
                                    if let km = value.as(Double.self) {
                                        AxisValueLabel(String(format: chartXUnit, km))
                                    }
                                }
                            }
                        case 1:
                            Chart {
                                ForEach(gctPoints) { pt in
                                    LineMark(
                                        x: .value(chartXLabel, pt.x),
                                        y: .value("GCT", pt.y)
                                    )
                                    .foregroundStyle(Color.green)
                                    .interpolationMethod(.catmullRom)
                                    .accessibilityLabel(isRussian ? "Время контакта с землей" : "Ground Contact Time")
                                    .accessibilityValue(String(format: isRussian ? "%.0f мс на расстоянии %.2f \(isMetric ? "км" : "миль")" : "%.0f ms at distance %.2f \(isMetric ? "km" : "mi")", pt.y, pt.x))
                                    
                                    AreaMark(
                                        x: .value(chartXLabel, pt.x),
                                        y: .value("GCT", pt.y)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.green.opacity(0.15), Color.clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)
                                }
                                
                                if let selectedDist = selectedDynamicsDistance {
                                    RuleMark(x: .value("Selected", selectedDist))
                                        .foregroundStyle(.secondary.opacity(0.5))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    
                                    if let sample = selectedDynamicsSample, let gct = sample.groundContactTime {
                                        PointMark(
                                            x: .value("Selected", selectedDist),
                                            y: .value("GCT", gct)
                                        )
                                        .foregroundStyle(Color.green)
                                        .symbol(Circle())
                                        .symbolSize(80)
                                    }
                                }
                            }
                            .frame(height: 160)
                            .chartXSelection(value: $selectedDynamicsDistance)
                            .chartXAxis {
                                AxisMarks(values: .automatic) { value in
                                    if let km = value.as(Double.self) {
                                        AxisValueLabel(String(format: chartXUnit, km))
                                    }
                                }
                            }
                        case 2:
                            VStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(isRussian ? "Длина шага" : "Stride Length")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    
                                    Chart {
                                        ForEach(stridePoints) { pt in
                                            LineMark(
                                                x: .value(chartXLabel, pt.x),
                                                y: .value("Stride", pt.y)
                                            )
                                            .foregroundStyle(Color.blue)
                                            .interpolationMethod(.catmullRom)
                                            .accessibilityLabel(isRussian ? "Длина шага" : "Stride Length")
                                            .accessibilityValue(String(format: isRussian ? "%.2f \(strideUnit) на расстоянии %.2f \(isMetric ? "км" : "миль")" : "%.2f \(strideUnit) at distance %.2f \(isMetric ? "km" : "mi")", pt.y, pt.x))
                                            
                                            AreaMark(
                                                x: .value(chartXLabel, pt.x),
                                                y: .value("Stride", pt.y)
                                            )
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color.blue.opacity(0.15), Color.clear],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .interpolationMethod(.catmullRom)
                                        }
                                        
                                        if let selectedDist = selectedDynamicsDistance {
                                            RuleMark(x: .value("Selected", selectedDist))
                                                .foregroundStyle(.secondary.opacity(0.5))
                                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                            
                                            if let sample = selectedDynamicsSample, let stride = sample.strideLength {
                                                PointMark(
                                                    x: .value("Selected", selectedDist),
                                                    y: .value("Stride", stride * strideMultiplier)
                                                )
                                                .foregroundStyle(Color.blue)
                                                .symbol(Circle())
                                                .symbolSize(80)
                                            }
                                        }
                                    }
                                    .frame(height: 100)
                                    .chartXSelection(value: $selectedDynamicsDistance)
                                    .chartXAxis {
                                        AxisMarks(values: .automatic) { value in
                                            if let km = value.as(Double.self) {
                                                AxisValueLabel(String(format: chartXUnit, km))
                                            }
                                        }
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(isRussian ? "Частота шагов (Каденс)" : "Cadence")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    
                                    Chart {
                                        ForEach(cadencePoints) { pt in
                                            LineMark(
                                                x: .value(chartXLabel, pt.x),
                                                y: .value("Cadence", pt.y)
                                            )
                                            .foregroundStyle(Color.orange)
                                            .interpolationMethod(.catmullRom)
                                            .accessibilityLabel(isRussian ? "Каденс" : "Cadence")
                                            .accessibilityValue(String(format: isRussian ? "%.0f шагов/мин на расстоянии %.2f \(isMetric ? "км" : "миль")" : "%.0f spm at distance %.2f \(isMetric ? "km" : "mi")", pt.y, pt.x))
                                            
                                            AreaMark(
                                                x: .value(chartXLabel, pt.x),
                                                y: .value("Cadence", pt.y)
                                            )
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color.orange.opacity(0.15), Color.clear],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .interpolationMethod(.catmullRom)
                                        }
                                        
                                        if let selectedDist = selectedDynamicsDistance {
                                            RuleMark(x: .value("Selected", selectedDist))
                                                .foregroundStyle(.secondary.opacity(0.5))
                                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                            
                                            if let sample = selectedDynamicsSample, let cad = sample.cadence {
                                                PointMark(
                                                    x: .value("Selected", selectedDist),
                                                    y: .value("Cadence", cad)
                                                )
                                                .foregroundStyle(Color.orange)
                                                .symbol(Circle())
                                                .symbolSize(80)
                                            }
                                        }
                                    }
                                    .frame(height: 100)
                                    .chartXSelection(value: $selectedDynamicsDistance)
                                    .chartXAxis {
                                        AxisMarks(values: .automatic) { value in
                                            if let km = value.as(Double.self) {
                                                AxisValueLabel(String(format: chartXUnit, km))
                                            }
                                        }
                                    }
                                }
                            }
                        default:
                            EmptyView()
                        }
                    }} else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 180)
                            .overlay(
                                Text("Графики беговой динамики")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            Divider()
        }
    }
    
    private var last30DaysRunningDynamicsAvg: (cadence: Double, stride: Double, osc: Double, gct: Double)? {
        let calendar = Calendar.current
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: .now) else { return nil }
        let runs = allActivities.filter {
            $0.sportType.lowercased() == "run" &&
            $0.startDate >= thirtyDaysAgo &&
            $0.averageCadence != nil
        }
        guard !runs.isEmpty else { return nil }
        
        let cadSum = runs.reduce(0.0) { $0 + ($1.averageCadence ?? 0.0) }
        let strideSum = runs.reduce(0.0) { $0 + ($1.averageStrideLength ?? 0.0) }
        let oscSum = runs.reduce(0.0) { $0 + ($1.averageVerticalOscillation ?? 0.0) }
        let gctSum = runs.reduce(0.0) { $0 + ($1.averageGroundContactTime ?? 0.0) }
        
        let count = Double(runs.count)
        return (
            cadence: cadSum / count,
            stride: strideSum / count,
            osc: oscSum / count,
            gct: gctSum / count
        )
    }
    
    private func diffText(label: String, diff: Double, format: String, inverseColor: Bool) -> some View {
        let isBetter: Bool
        if inverseColor {
            isBetter = diff < 0
        } else {
            isBetter = diff > 0
        }
        let color: Color = abs(diff) < 0.001 ? .secondary : (isBetter ? .green : .red)
        return HStack(spacing: 4) {
            Text("\(label):")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: format, diff))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2).fontWeight(.bold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.subheadline).fontWeight(.semibold)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SplitsSectionView: View {
    let splits: [KilometerSplit]
    let isMetric: Bool
    
    private var bestPace: Double {
        splits.map { $0.pace }.min() ?? 0.0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isMetric ? "КМ" : "МИЛЯ").frame(width: 40, alignment: .leading)
                Text("Темп").frame(maxWidth: .infinity, alignment: .leading)
                Text("Пульс").frame(width: 60, alignment: .trailing)
                Text("Высота").frame(width: 70, alignment: .trailing)
            }
            .font(.caption).fontWeight(.bold)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            
            Divider()

            ForEach(splits) { split in
                HStack {
                    Text("\(split.index)").bold().frame(width: 40, alignment: .leading)
                    
                    HStack(spacing: 4) {
                        Text(formattedPace(split.pace))
                        if split.pace == bestPace {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(split.avgHeartRate.map { String(format: "%.0f", $0) } ?? "--").frame(width: 60, alignment: .trailing)
                    let elevUnit = isMetric ? " м" : " фт"
                    Text(String(format: "%+.0f\(elevUnit)", split.elevationChange)).frame(width: 70, alignment: .trailing)
                }
                .font(.subheadline)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(split.pace == bestPace ? Color.yellow.opacity(0.12) : Color.clear)
                
                Divider()
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func formattedPace(_ seconds: Double) -> String {
        guard seconds > 0 && seconds < 3600 else { return "--:--" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

}

private struct DynamicsGridTile: View {
    let title: String
    let value: String
    let zone: DynamicsZone?
    let scoreText: String
    let percent: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 4)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, max(0.0, percent))))
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: -90))
            }
            .frame(width: 44, height: 44)
            
            if let _ = zone {
                Text(scoreText)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.12), in: Capsule())
            } else {
                Text(AppLanguage.isRussian ? "Метрика" : "Metric")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }
            
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct LRBalanceBarometer: View {
    let leftPercent: Double
    let zone: DynamicsZone
    let isRussian: Bool
    
    private var rightPercent: Double {
        100.0 - leftPercent
    }
    
    private var zoneColor: Color {
        switch zone {
        case .optimal: return .purple
        case .good: return .green
        case .fair, .poor: return .red
        }
    }
    
    private var zoneText: String {
        if isRussian {
            switch zone {
            case .optimal: return "Симметрия"
            case .good: return "Норма"
            case .fair, .poor: return "Асимметрия"
            }
        } else {
            switch zone {
            case .optimal: return "Symmetry"
            case .good: return "Normal"
            case .fair, .poor: return "Asymmetry"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(format: "%.1f%% Л", leftPercent))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                
                Spacer()
                
                Text(zoneText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(zoneColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(zoneColor.opacity(0.12), in: Capsule())
                
                Spacer()
                
                Text(String(format: "%.1f%% П", rightPercent))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.purple)
            }
            
            // Barometer track
            GeometryReader { geo in
                let width = geo.size.width
                let clampedLeft = max(45.0, min(55.0, leftPercent))
                let indicatorPosition = CGFloat((clampedLeft - 45.0) / 10.0) * width
                
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [
                            .red, .orange, .green, .purple, .green, .orange, .red
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(Capsule())
                    
                    // Tick mark at 50%
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 2, height: 12)
                        .offset(x: width / 2 - 1)
                    
                    // Thumb / Pointer
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(radius: 2)
                        .overlay(Circle().stroke(zoneColor, lineWidth: 3))
                        .offset(x: indicatorPosition - 7)
                }
            }
            .frame(height: 12)
            
            HStack {
                Text("45% L")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("50/50")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("45% R")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// SwiftUI ShareSheet wrapper using UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
