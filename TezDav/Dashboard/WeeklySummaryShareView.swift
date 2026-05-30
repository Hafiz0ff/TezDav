import SwiftUI
import MapKit
import SwiftData

struct WeeklySummaryShareView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Query private var userSettings: [UserSettings]
    
    @State private var mapImage: UIImage? = nil
    @State private var isGenerating = false
    @State private var exportItem: UIImage? = nil
    @State private var showSaveSuccess = false
    
    private var isMetric: Bool {
        userSettings.first?.isMetric ?? true
    }
    
    // Calculates Monday of the current week
    private var startOfWeek: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 2 // Monday
        return calendar.date(from: components) ?? Date().addingTimeInterval(-86400 * 7)
    }
    
    private var weeklyActivities: [Activity] {
        let start = startOfWeek
        return activities.filter { $0.startDate >= start }
    }
    
    private var totalDistanceMeters: Double {
        weeklyActivities.reduce(0.0) { $0 + $1.distanceMeters }
    }
    
    private var totalDurationSeconds: TimeInterval {
        weeklyActivities.reduce(0.0) { $0 + $1.movingTime }
    }
    
    private var longestActivity: Activity? {
        weeklyActivities.max(by: { $0.distanceMeters < $1.distanceMeters })
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isGenerating {
                    VStack {
                        ProgressView("Подготовка сводки...")
                            .tint(.orange)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            if weeklyActivities.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 64))
                                        .foregroundColor(.secondary)
                                    Text("Нет тренировок на этой неделе")
                                        .font(.headline)
                                    Text("Начните тренироваться, чтобы сгенерировать сводный отчет.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                                .frame(height: 300)
                            } else if let mapImg = mapImage {
                                cardPreview(mapImage: mapImg)
                                    .shadow(radius: 12)
                                    .padding(.top, 16)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons
                if !weeklyActivities.isEmpty {
                    VStack(spacing: 12) {
                        Button(action: {
                            Task { await shareCard() }
                        }) {
                            Label("Поделиться сводкой", systemImage: "square.and.arrow.up")
                                .bold()
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            Task { await saveToPhotos() }
                        }) {
                            Label("Сохранить в Фото", systemImage: "square.and.arrow.down")
                                .bold()
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                } else {
                    Button("Закрыть") { dismiss() }
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("Недельный отчет")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .task {
                if !weeklyActivities.isEmpty {
                    await loadMapSnapshot()
                }
            }
            .sheet(item: Binding<ShareSheetItem?>(
                get: { exportItem.map { ShareSheetItem(image: $0) } },
                set: { exportItem = $0?.image }
            )) { item in
                HeatmapShareSheet(activityItems: [item.image])
            }
            .alert("Успешно", isPresented: $showSaveSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Сводка сохранена в медиатеку.")
            }
        }
    }
    
    struct ShareSheetItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    
    @ViewBuilder
    private func cardPreview(mapImage: UIImage) -> some View {
        squareLayout(mapImage: mapImage)
            .frame(width: 320, height: 320)
            .cornerRadius(16)
            .clipped()
    }
    
    // Square card layout
    private func squareLayout(mapImage: UIImage) -> some View {
        ZStack {
            // Dark premium sunset gradient
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.14), Color(red: 0.05, green: 0.05, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Map with transparency
            Image(uiImage: mapImage)
                .resizable()
                .scaledToFill()
                .frame(width: 320, height: 320)
                .opacity(0.4)
            
            // Text overlays
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("НЕДЕЛЬНАЯ СВОДКА")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                        Text(weeklyDateRangeText())
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("TezDav")
                        .font(.system(size: 14, weight: .black))
                        .italic()
                        .foregroundColor(.orange)
                }
                .padding(14)
                
                Spacer()
                
                // Big Metric
                VStack(alignment: .leading, spacing: 4) {
                    Text("СУММАРНАЯ ДИСТАНЦИЯ")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.gray)
                    Text(formatDistance(totalDistanceMeters))
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                
                Spacer()
                
                // Detailed Stats Row
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("АКТИВНОСТЕЙ")
                            .font(.system(size: 7))
                            .foregroundColor(.gray)
                        Text("\(weeklyActivities.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ВРЕМЯ ДВИЖЕНИЯ")
                            .font(.system(size: 7))
                            .foregroundColor(.gray)
                        Text(formatDuration(totalDurationSeconds))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if let longest = longestActivity {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("РЕКОРД НЕДЕЛИ")
                                .font(.system(size: 7))
                                .foregroundColor(.gray)
                            Text(formatDistance(longest.distanceMeters))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 320, height: 320)
    }
    
    // MARK: - Logic / Generation
    
    private func loadMapSnapshot() async {
        isGenerating = true
        let size = CGSize(width: 1024, height: 1024)
        mapImage = await generateWeeklyHeatmapSnapshot(size: size)
        isGenerating = false
    }
    
    private func generateWeeklyHeatmapSnapshot(size: CGSize) async -> UIImage? {
        let weeklyTracks = weeklyActivities.compactMap { act -> [CLLocationCoordinate2D]? in
            guard let poly = act.encodedPolyline, !poly.isEmpty else { return nil }
            return PolylineEncoder.decode(polyline: poly)
        }.filter { !$0.isEmpty }
        
        let allCoords = weeklyTracks.flatMap { $0 }
        guard !allCoords.isEmpty else { return nil }
        
        // Calculate bounding box
        var minLat = 90.0
        var maxLat = -90.0
        var minLng = 180.0
        var maxLng = -180.0
        for c in allCoords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude)
            maxLng = max(maxLng, c.longitude)
        }
        
        let options = MKMapSnapshotter.Options()
        options.size = size
        options.mapType = .standard
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0, longitude: (minLng + maxLng) / 2.0)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.5 + 0.003, longitudeDelta: (maxLng - minLng) * 1.5 + 0.003)
        options.region = MKCoordinateRegion(center: center, span: span)
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        
        let snapshotter = MKMapSnapshotter(options: options)
        do {
            let snapshot = try await snapshotter.start()
            let baseImage = snapshot.image
            
            UIGraphicsBeginImageContextWithOptions(baseImage.size, true, baseImage.scale)
            baseImage.draw(at: .zero)
            
            if let context = UIGraphicsGetCurrentContext() {
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.setStrokeColor(UIColor.orange.withAlphaComponent(0.85).cgColor)
                context.setLineWidth(6.0)
                
                for route in weeklyTracks {
                    context.beginPath()
                    let first = snapshot.point(for: route[0])
                    context.move(to: first)
                    for i in 1..<route.count {
                        let p = snapshot.point(for: route[i])
                        context.addLine(to: p)
                    }
                    context.strokePath()
                }
            }
            
            let finalImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return finalImage
        } catch {
            print("Weekly snapshot failed: \(error)")
            return nil
        }
    }
    
    @MainActor
    private func renderFinalImage() -> UIImage? {
        guard let mapImg = mapImage else { return nil }
        let finalSize = CGSize(width: 1080, height: 1080)
        
        let renderView = ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.14), Color(red: 0.05, green: 0.05, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            Image(uiImage: mapImg)
                .resizable()
                .scaledToFill()
                .frame(width: finalSize.width, height: finalSize.height)
                .opacity(0.4)
            
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("НЕДЕЛЬНАЯ СВОДКА")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.orange)
                        Text(weeklyDateRangeText())
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text("TezDav")
                        .font(.system(size: 42, weight: .black))
                        .italic()
                        .foregroundColor(.orange)
                }
                .padding(54)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("СУММАРНАЯ ДИСТАНЦИЯ")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.gray)
                    Text(formatDistance(totalDistanceMeters))
                        .font(.system(size: 96, weight: .black))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 54)
                
                Spacer()
                
                HStack(spacing: 60) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("АКТИВНОСТЕЙ")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                        Text("\(weeklyActivities.count)")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ВРЕМЯ ДВИЖЕНИЯ")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                        Text(formatDuration(totalDurationSeconds))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if let longest = longestActivity {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("РЕКОРД НЕДЕЛИ")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                            Text(formatDistance(longest.distanceMeters))
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(54)
            }
        }
        .frame(width: finalSize.width, height: finalSize.height)
        
        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 1.0
        return renderer.uiImage
    }
    
    private func shareCard() async {
        if let finalImage = await MainActor.run(body: { renderFinalImage() }) {
            exportItem = finalImage
        }
    }
    
    private func saveToPhotos() async {
        if let finalImage = await MainActor.run(body: { renderFinalImage() }) {
            UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
            showSaveSuccess = true
        }
    }
    
    // MARK: - Helpers
    
    private func weeklyDateRangeText() -> String {
        let calendar = Calendar.current
        let start = startOfWeek
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? Date()
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.locale = Locale(identifier: "ru_RU")
        return "\(df.string(from: start)) - \(df.string(from: end))".uppercased()
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let divider = isMetric ? 1000.0 : 1609.34
        let unit = isMetric ? "км" : "миль"
        return String(format: "%.1f %@", meters / divider, unit)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 {
            return String(format: "%d ч %d мин", h, m)
        } else {
            return String(format: "%d мин", m)
        }
    }
}
