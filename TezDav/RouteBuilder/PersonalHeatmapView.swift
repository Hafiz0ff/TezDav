import SwiftUI
import MapKit
import SwiftData

struct HeatmapTrack: Identifiable, Sendable {
    let id: Int64
    let coordinates: [CLLocationCoordinate2D]
    let sportType: String
    let distanceMeters: Double
}

struct PersonalHeatmapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var activities: [Activity]
    @Query private var userSettings: [UserSettings]
    
    private var activeUserSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }
    
    @State private var tracks: [HeatmapTrack] = []
    @State private var isLoading = false
    @State private var progressText = ""
    
    // Filters and Styling
    @State private var filterSport = "All" // "All", "Run", "Ride", "Walk", "Swim"
    @State private var opacity: Double = 0.6
    @State private var lineWidth: Double = 3.5
    @State private var colorScheme = HeatmapColorScheme.orange
    @State private var mapStyle = MapStyleSelection.standard
    @State private var periodDays: Int? = nil // nil = All time, 30, 180, 365
    
    // Zone stats popup
    @State private var showZoneCard = false
    @State private var selectedZoneName = ""
    @State private var selectedZoneCount = 0
    @State private var selectedZoneDistance = 0.0
    @State private var selectedZoneMaxDistance = 0.0
    
    // Map State
    @State private var cameraCenter: CLLocationCoordinate2D?
    @State private var cameraZoom: Float?
    @State private var currentRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
    )
    
    // Share Sheet State
    @State private var isExporting = false
    @State private var exportItem: ShareImageItem? = nil
    
    struct ShareImageItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    
    enum HeatmapColorScheme: String, CaseIterable, Identifiable {
        case orange = "Оранжевая"
        case green = "Зеленый неон"
        case blue = "Синий лед"
        case multisport = "Мультиспорт"
        
        var id: String { rawValue }
    }
    
    enum MapStyleSelection: String, CaseIterable, Identifiable {
        case standard = "Схема"
        case imagery = "Спутник"
        case hybrid = "Гибрид"
        
        var id: String { rawValue }
    }
    
    private var filteredTracks: [HeatmapTrack] {
        tracks.filter { track in
            // Sport check
            let sportMatch = (filterSport == "All" || track.sportType == filterSport)
            
            // Date check
            var dateMatch = true
            if let days = periodDays, let activity = activities.first(where: { $0.stravaId == track.id }) {
                let limitDate = Date().addingTimeInterval(-86400 * Double(days))
                dateMatch = activity.startDate >= limitDate
            }
            
            return sportMatch && dateMatch
        }
    }
    
    private var totalDistanceText: String {
        let totalMeters = filteredTracks.reduce(0.0) { $0 + $1.distanceMeters }
        return formatDistanceText(totalMeters)
    }
    
    private func formatDistanceText(_ meters: Double) -> String {
        let isMetric = activeUserSettings.isMetric
        let divisor = isMetric ? 1000.0 : 1609.34
        let unit = isMetric ? "км" : "миль"
        return String(format: "%.1f %@", meters / divisor, unit)
    }
    
    var body: some View {
        ZStack {
            // Main Map View with Tile Overlay
            TezDavMapView(
                heatmapTracks: filteredTracks,
                filterSport: filterSport,
                periodDays: periodDays,
                opacity: opacity,
                lineWidth: lineWidth,
                colorScheme: colorScheme,
                mapStyle: mapStyle,
                onZoneSelected: { coordinate, zoneName, count, totalDist, maxDist in
                    self.selectedZoneName = zoneName
                    self.selectedZoneCount = count
                    self.selectedZoneDistance = totalDist
                    self.selectedZoneMaxDistance = maxDist
                    withAnimation {
                        self.showZoneCard = true
                    }
                },
                cameraCenter: $cameraCenter,
                cameraZoom: $cameraZoom
            )
            .ignoresSafeArea()
            
            // UI Overlays
            VStack {
                // Top floating selector (Sport type & Map type & Period)
                topControlPanel
                
                Spacer()
                
                // Floating District Info Card
                if showZoneCard {
                    zoneStatsCard
                        .padding(.bottom, 8)
                }
                
                // Bottom drawer control panel
                bottomControlDrawer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // Loading Overlay
            if isLoading {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.orange)
                        
                        Text(progressText)
                            .foregroundColor(.white)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground).opacity(0.95)))
                }
            }
        }
        .task {
            await loadHeatmapTracks()
        }
        .sheet(item: $exportItem) { item in
            HeatmapShareSheet(activityItems: [item.image])
        }
    }
    
    // MARK: - Subviews
    
    // MARK: - Subviews
    
    private var sportFilterView: some View {
        HStack(spacing: 4) {
            ForEach(["All", "Run", "Ride", "Walk", "Swim"], id: \.self) { sport in
                Button {
                    HapticManager.trigger(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        filterSport = sport
                    }
                } label: {
                    Text(sport == "All" ? "Все" : (sport == "Run" ? "Бег" : (sport == "Ride" ? "Вело" : (sport == "Walk" ? "Ход" : "Плав"))))
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(filterSport == sport ? Color.accentPrimary.opacity(0.12) : Color.white.opacity(0.04))
                        .foregroundColor(filterSport == sport ? Color.accentPrimary : Color.textSecondaryReadable)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(filterSport == sport ? Color.accentPrimary.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
            }
        }
    }
    
    private var mapStyleFilterView: some View {
        HStack(spacing: 4) {
            ForEach(MapStyleSelection.allCases) { style in
                Button {
                    HapticManager.trigger(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        mapStyle = style
                    }
                } label: {
                    Text(style.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(mapStyle == style ? Color.accentPrimary.opacity(0.12) : Color.white.opacity(0.04))
                        .foregroundColor(mapStyle == style ? Color.accentPrimary : Color.textSecondaryReadable)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(mapStyle == style ? Color.accentPrimary.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
            }
        }
    }
    
    private var periodFilterView: some View {
        HStack(spacing: 6) {
            let options: [(label: String, val: Int?)] = [
                ("30д", 30),
                ("6м", 180),
                ("Год", 365),
                ("Всё время", nil)
            ]
            ForEach(options, id: \.label) { opt in
                Button {
                    HapticManager.trigger(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        periodDays = opt.val
                    }
                } label: {
                    Text(opt.label)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(periodDays == opt.val ? Color.accentPrimary.opacity(0.12) : Color.white.opacity(0.04))
                        .foregroundColor(periodDays == opt.val ? Color.accentPrimary : Color.textSecondaryReadable)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(periodDays == opt.val ? Color.accentPrimary.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
            }
        }
    }

    private var topControlPanel: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    sportFilterView
                    Spacer(minLength: 4)
                    mapStyleFilterView
                }
                
                periodFilterView
            }
            .padding(8)
            .liquidGlassCard(cornerRadius: 16)
        }
    }
    
    private var zoneStatsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.accentPrimary)
                    .font(.headline)
                
                Text(selectedZoneName)
                    .font(.headline)
                    .bold()
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showZoneCard = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondaryReadable)
                        .font(.title3)
                }
            }
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ПОСЕЩЕНИЙ")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.textSecondaryReadable)
                    Text("\(selectedZoneCount)")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("КИЛОМЕТРАЖ")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.textSecondaryReadable)
                    Text(formatDistanceText(selectedZoneDistance))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("РЕКОРД ЗОНЫ")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.textSecondaryReadable)
                    Text(formatDistanceText(selectedZoneMaxDistance))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 16, tint: .emerald)
    }
    
    private var bottomControlDrawer: some View {
        VStack(spacing: 12) {
            // Stats Panel
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Треков на карте")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.textSecondaryReadable)
                    Text("\(filteredTracks.count)")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Суммарная дистанция")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.textSecondaryReadable)
                    Text(totalDistanceText)
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                }
            }
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Customization Options
            VStack(spacing: 8) {
                // Color Scheme Choice
                HStack {
                    Text("Палитра свечения")
                        .font(.subheadline.bold())
                        .foregroundColor(.textPrimary)
                    Spacer()
                    
                    Menu {
                        Picker("Схема", selection: $colorScheme) {
                            ForEach(HeatmapColorScheme.allCases) { scheme in
                                Text(scheme.rawValue).tag(scheme)
                            }
                        }
                    } label: {
                        HStack {
                            Text(colorScheme.rawValue)
                                .font(.footnote.weight(.semibold))
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                
                // Opacity slider
                HStack {
                    Image(systemName: "circle.circle")
                        .foregroundColor(.textSecondaryReadable)
                    Text("Свечение")
                        .font(.footnote)
                        .foregroundColor(.textSecondaryReadable)
                    Slider(value: $opacity, in: 0.1...1.0)
                        .tint(.orange)
                    Text(String(format: "%.0f%%", opacity * 100))
                        .font(.caption)
                        .foregroundColor(.textPrimary)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                
                // Thickness slider
                HStack {
                    Image(systemName: "line.horizontal.3")
                        .foregroundColor(.textSecondaryReadable)
                    Text("Толщина")
                        .font(.footnote)
                        .foregroundColor(.textSecondaryReadable)
                    Slider(value: $lineWidth, in: 1.0...8.0)
                        .tint(.orange)
                    Text(String(format: "%.1f px", lineWidth))
                        .font(.caption)
                        .foregroundColor(.textPrimary)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Sharing and Refresh buttons
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        await loadHeatmapTracks()
                    }
                }) {
                    Label("Обновить", systemImage: "arrow.clockwise")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Button(action: {
                    Task {
                        await generateAndShareHeatmap()
                    }
                }) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 4)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text("Экспорт карты")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange.gradient)
                    .cornerRadius(10)
                }
                .disabled(isExporting)
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 16)
    }
    
    // MARK: - Logic / Helper functions
    
    private func loadHeatmapTracks() async {
        isLoading = true
        progressText = "Инициализация треков базы данных..."
        
        let allActs = activities
        let total = allActs.count
        var loadedTracks: [HeatmapTrack] = []
        
        for (idx, activity) in allActs.enumerated() {
            progressText = "Загрузка маршрутов... (\(idx + 1)/\(total))"
            
            var coords: [CLLocationCoordinate2D] = []
            
            if let poly = activity.encodedPolyline, !poly.isEmpty {
                coords = PolylineEncoder.decode(polyline: poly)
            } else {
                let activityId = activity.stravaId
                let descriptor = FetchDescriptor<ActivityStreamSample>(
                    predicate: #Predicate<ActivityStreamSample> { $0.activityId == activityId }
                )
                
                if let samples = try? modelContext.fetch(descriptor) {
                    let sortedSamples = samples.sorted { $0.offsetSeconds < $1.offsetSeconds }
                    let points = sortedSamples.compactMap { sample -> CLLocationCoordinate2D? in
                        guard let lat = sample.latitude, let lng = sample.longitude else { return nil }
                        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    }
                    
                    if !points.isEmpty {
                        coords = downsample(coordinates: points, maxPoints: 150)
                        let encoded = PolylineEncoder.encode(coordinates: coords)
                        activity.encodedPolyline = encoded
                        try? modelContext.save()
                    }
                }
            }
            
            if !coords.isEmpty {
                loadedTracks.append(HeatmapTrack(
                    id: activity.stravaId,
                    coordinates: coords,
                    sportType: activity.sportType,
                    distanceMeters: activity.distanceMeters
                ))
            }
        }
        
        tracks = loadedTracks
        
        // Auto position map region to fit all tracks, if available
        let allCoords = loadedTracks.flatMap { $0.coordinates }
        if let autoRegion = bounds(for: allCoords) {
            currentRegion = autoRegion
            cameraCenter = autoRegion.center
            cameraZoom = Float(log2(360.0 / max(0.001, autoRegion.span.latitudeDelta))) - 1.0
        }
        
        isLoading = false
    }
    
    private func downsample(coordinates: [CLLocationCoordinate2D], maxPoints: Int) -> [CLLocationCoordinate2D] {
        let count = coordinates.count
        guard count > maxPoints else { return coordinates }
        
        let strideValue = Double(count) / Double(maxPoints)
        var result: [CLLocationCoordinate2D] = []
        
        for i in 0..<maxPoints {
            let index = Int(round(Double(i) * strideValue))
            if index < count {
                result.append(coordinates[index])
            }
        }
        
        if let last = coordinates.last, !result.isEmpty,
           (result.last?.latitude != last.latitude || result.last?.longitude != last.longitude) {
            result.append(last)
        }
        
        return result
    }
    
    private func bounds(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        
        var minLat = 90.0
        var maxLat = -90.0
        var minLng = 180.0
        var maxLng = -180.0
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLng = min(minLng, coord.longitude)
            maxLng = max(maxLng, coord.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLng + maxLng) / 2.0
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.35 + 0.005,
            longitudeDelta: (maxLng - minLng) * 1.35 + 0.005
        )
        return MKCoordinateRegion(center: center, span: span)
    }
    
    private func getUIKitColor(for track: HeatmapTrack, scheme: HeatmapColorScheme) -> UIColor {
        switch scheme {
        case .orange:
            return .orange
        case .green:
            return .green
        case .blue:
            return .systemBlue
        case .multisport:
            if track.sportType == "Run" {
                return .green
            } else if track.sportType == "Ride" {
                return .systemBlue
            } else {
                return .systemPurple
            }
        }
    }
    
    // MARK: - Snapshot Generator
    
    @MainActor
    private func generateAndShareHeatmap() async {
        isExporting = true
        
        if let center = cameraCenter {
            let zoomLevel = cameraZoom ?? 12.0
            let delta = 360.0 / pow(2.0, Double(zoomLevel))
            currentRegion = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
            )
        }
        
        let options = MKMapSnapshotter.Options()
        options.region = currentRegion
        options.size = CGSize(width: 1024, height: 1024)
        
        switch mapStyle {
        case .standard:
            options.mapType = .standard
        case .imagery:
            options.mapType = .satellite
        case .hybrid:
            options.mapType = .hybrid
        }
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        do {
            let snapshot = try await snapshotter.start()
            let baseImage = snapshot.image
            
            UIGraphicsBeginImageContextWithOptions(baseImage.size, true, baseImage.scale)
            baseImage.draw(at: .zero)
            
            guard let context = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                isExporting = false
                return
            }
            
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            let currentTracks = filteredTracks
            for track in currentTracks {
                guard !track.coordinates.isEmpty else { continue }
                
                context.beginPath()
                let strokeColor = getUIKitColor(for: track, scheme: colorScheme).withAlphaComponent(CGFloat(opacity))
                context.setStrokeColor(strokeColor.cgColor)
                context.setLineWidth(CGFloat(lineWidth) * 2.0)
                
                let firstPoint = snapshot.point(for: track.coordinates[0])
                context.move(to: firstPoint)
                
                for i in 1..<track.coordinates.count {
                    let point = snapshot.point(for: track.coordinates[i])
                    context.addLine(to: point)
                }
                
                context.strokePath()
            }
            
            let finalImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let img = finalImage {
                exportItem = ShareImageItem(image: img)
            }
        } catch {
            print("Failed to generate map snapshot: \(error)")
        }
        
        isExporting = false
    }
}

struct HeatmapShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
