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
    @State private var filterSport = "All" // "All", "Run", "Ride"
    @State private var opacity: Double = 0.6
    @State private var lineWidth: Double = 3.5
    @State private var colorScheme = HeatmapColorScheme.orange
    @State private var mapStyle = MapStyleSelection.standard
    
    // Map State
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var currentRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.56, longitude: 68.79),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
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
        
        var style: MapStyle {
            switch self {
            case .standard: return .standard
            case .imagery: return .imagery
            case .hybrid: return .hybrid
            }
        }
    }
    
    private var filteredTracks: [HeatmapTrack] {
        tracks.filter { track in
            if filterSport == "All" { return true }
            return track.sportType == filterSport
        }
    }
    
    private var totalDistanceText: String {
        let totalMeters = filteredTracks.reduce(0.0) { $0 + $1.distanceMeters }
        let isMetric = activeUserSettings.isMetric
        let divisor = isMetric ? 1000.0 : 1609.34
        let unit = isMetric ? "км" : "миль"
        return String(format: "%.1f %@", totalMeters / divisor, unit)
    }
    
    var body: some View {
        ZStack {
            // Main Map View
            Map(position: $mapPosition, interactionModes: .all) {
                ForEach(filteredTracks) { track in
                    MapPolyline(coordinates: track.coordinates)
                        .stroke(
                            getSwiftUIColor(for: track, scheme: colorScheme).opacity(opacity),
                            style: StrokeStyle(lineWidth: CGFloat(lineWidth), lineCap: .round, lineJoin: .round)
                        )
                }
            }
            .mapStyle(mapStyle.style)
            .onMapCameraChange { context in
                currentRegion = context.region
            }
            
            // UI Overlays
            VStack {
                // Top floating selector (Sport type & Map type)
                topControlPanel
                
                Spacer()
                
                // Bottom drawer control panel (Opacity, width, color schemes, stats)
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
    
    private var topControlPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Sport type filter picker
                Picker("Вид спорта", selection: $filterSport) {
                    Text("Все").tag("All")
                    Text("Бег").tag("Run")
                    Text("Вело").tag("Ride")
                }
                .pickerStyle(.segmented)
                
                // Map Style picker
                Picker("Тип карты", selection: $mapStyle) {
                    ForEach(MapStyleSelection.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
            )
        }
    }
    
    private var bottomControlDrawer: some View {
        VStack(spacing: 14) {
            // Stats Panel
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Активностей на карте")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(filteredTracks.count)")
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Общая дистанция")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(totalDistanceText)
                        .font(.headline)
                }
            }
            
            Divider()
            
            // Customization Options
            VStack(spacing: 10) {
                // Color Scheme Choice
                HStack {
                    Text("Цветовая схема")
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Picker("Схема", selection: $colorScheme) {
                        ForEach(HeatmapColorScheme.allCases) { scheme in
                            Text(scheme.rawValue).tag(scheme)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.orange)
                }
                
                // Opacity slider
                HStack {
                    Image(systemName: "circle.circle")
                        .foregroundColor(.secondary)
                    Text("Свечение")
                        .font(.footnote)
                    Slider(value: $opacity, in: 0.1...1.0)
                        .tint(.orange)
                    Text(String(format: "%.0f%%", opacity * 100))
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                
                // Thickness slider
                HStack {
                    Image(systemName: "line.horizontal.3")
                        .foregroundColor(.secondary)
                    Text("Толщина")
                        .font(.footnote)
                    Slider(value: $lineWidth, in: 1.0...8.0)
                        .tint(.orange)
                    Text(String(format: "%.1f px", lineWidth))
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
            
            Divider()
            
            // Sharing and Refresh buttons
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        await loadHeatmapTracks()
                    }
                }) {
                    Label("Обновить", systemImage: "arrow.clockwise")
                        .bold()
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.15)))
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
                            .bold()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange))
                }
                .disabled(isExporting)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
        )
    }
    
    // MARK: - Logic / Helper functions
    
    private func loadHeatmapTracks() async {
        isLoading = true
        progressText = "Инициализация базы данных..."
        
        let allActs = activities
        let total = allActs.count
        var loadedTracks: [HeatmapTrack] = []
        
        // Ensure background context calculations do not block main UI thread
        for (idx, activity) in allActs.enumerated() {
            progressText = "Обработка треков... (\(idx + 1)/\(total))"
            
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
                        // Downsample for performance (approx 150 points is enough for heat trace)
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
            mapPosition = .region(autoRegion)
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
            latitudeDelta: (maxLat - minLat) * 1.3 + 0.005,
            longitudeDelta: (maxLng - minLng) * 1.3 + 0.005
        )
        return MKCoordinateRegion(center: center, span: span)
    }
    
    private func getSwiftUIColor(for track: HeatmapTrack, scheme: HeatmapColorScheme) -> Color {
        switch scheme {
        case .orange:
            return .orange
        case .green:
            return .green
        case .blue:
            return .blue
        case .multisport:
            if track.sportType == "Run" {
                return .green
            } else if track.sportType == "Ride" {
                return .blue
            } else {
                return .purple
            }
        }
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
        
        let options = MKMapSnapshotter.Options()
        options.region = currentRegion
        options.size = CGSize(width: 1024, height: 1024)
        
        // Configure map style for export options
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
            
            // Draw overlay tracks in UIKit Graphics Context
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
                context.setLineWidth(CGFloat(lineWidth) * 2.0) // Scale line width up slightly for high-res export
                
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

// System Share sheet wrapper for SwiftUI sheet
struct HeatmapShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
