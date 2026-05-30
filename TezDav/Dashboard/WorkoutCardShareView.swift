import SwiftUI
import MapKit
import SwiftData

enum ShareTheme: String, CaseIterable, Identifiable {
    case dark = "Тёмная"
    case light = "Светлая"
    case gradient = "Градиент"
    
    var id: String { rawValue }
}

enum ShareFormat: String, CaseIterable, Identifiable {
    case square = "Квадрат (1:1)"
    case stories = "Stories (9:16)"
    
    var id: String { rawValue }
}

struct WorkoutCardShareView: View {
    let activity: Activity
    @Environment(\.dismiss) private var dismiss
    
    @State private var theme: ShareTheme = .dark
    @State private var format: ShareFormat = .square
    @State private var mapImage: UIImage? = nil
    @State private var isGeneratingMap = false
    @State private var exportItem: UIImage? = nil
    @State private var isSharing = false
    @State private var showSaveSuccess = false
    
    // User settings context for units
    @Query private var userSettings: [UserSettings]
    private var isMetric: Bool {
        userSettings.first?.isMetric ?? true
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Previews area
                if isGeneratingMap {
                    VStack {
                        ProgressView("Подготовка карты...")
                            .tint(.orange)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            if let mapImg = mapImage {
                                cardPreview(mapImage: mapImg)
                                    .shadow(radius: 12)
                                    .padding(.top, 16)
                            } else {
                                Text("Не удалось загрузить карту для шаринга")
                                    .foregroundColor(.secondary)
                                    .frame(height: 300)
                            }
                            
                            // Control Selectors
                            VStack(spacing: 16) {
                                Picker("Формат", selection: $format) {
                                    ForEach(ShareFormat.allCases) { f in
                                        Text(f.rawValue).tag(f)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: format) { _ in
                                    Task { await loadMapSnapshot() }
                                }
                                
                                Picker("Тема", selection: $theme) {
                                    ForEach(ShareTheme.allCases) { t in
                                        Text(t.rawValue).tag(t)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: theme) { _ in
                                    Task { await loadMapSnapshot() }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Task { await shareCard() }
                    }) {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
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
            }
            .navigationTitle("Поделиться тренировкой")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
            .task {
                await loadMapSnapshot()
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
                Text("Карточка сохранена в медиатеку вашего устройства.")
            }
        }
    }
    
    struct ShareSheetItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    
    // MARK: - Previews Layouts
    
    @ViewBuilder
    private func cardPreview(mapImage: UIImage) -> some View {
        let size: CGSize = format == .square ? CGSize(width: 320, height: 320) : CGSize(width: 250, height: 444)
        
        let card = Group {
            if format == .square {
                squareLayout(mapImage: mapImage)
            } else {
                storiesLayout(mapImage: mapImage)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .cornerRadius(16)
    }
    
    // 1:1 Square layout
    @ViewBuilder
    private func squareLayout(mapImage: UIImage) -> some View {
        ZStack {
            backgroundGradient()
            
            // Map
            Image(uiImage: mapImage)
                .resizable()
                .scaledToFill()
                .frame(width: 320, height: 320)
                .opacity(theme == .light ? 0.8 : 0.6)
            
            // Bottom Gradient Overlay for legibility
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.black.opacity(0.85), Color.black.opacity(0.3), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 140)
            }
            
            // Stats & Content
            VStack(alignment: .leading, spacing: 0) {
                // Header (Type, Date & Logo)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sportEmojiAndName())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                        Text(formatDate(activity.startDate))
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
                
                // Metrics
                HStack(alignment: .bottom, spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Дистанция")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                        Text(formatDistance(activity.distanceMeters))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Время")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                        Text(formatTime(activity.movingTime))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Темп / Скорость")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                        Text(formatPaceOrSpeed(meters: activity.distanceMeters, seconds: activity.movingTime))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 320, height: 320)
    }
    
    // 9:16 Stories layout
    @ViewBuilder
    private func storiesLayout(mapImage: UIImage) -> some View {
        ZStack {
            backgroundGradient()
            
            // Map
            Image(uiImage: mapImage)
                .resizable()
                .scaledToFill()
                .frame(width: 250, height: 444)
                .opacity(theme == .light ? 0.75 : 0.55)
            
            // Bottom Gradient Overlay
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.black.opacity(0.9), Color.black.opacity(0.4), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 200)
            }
            
            // Stats & Content
            VStack(alignment: .leading, spacing: 0) {
                // Header (Logo in center or right)
                HStack {
                    Text("TezDav")
                        .font(.system(size: 14, weight: .black))
                        .italic()
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(sportEmojiAndName())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                        Text(formatDate(activity.startDate))
                            .font(.system(size: 7))
                            .foregroundColor(.gray)
                    }
                }
                .padding(12)
                
                Spacer()
                
                // Large title text style metrics stacked vertically for stories
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("ДИСТАНЦИЯ")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.orange)
                        Text(formatDistance(activity.distanceMeters))
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("ВРЕМЯ ДВИЖЕНИЯ")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.orange)
                        Text(formatTime(activity.movingTime))
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("СРЕДНИЙ ТЕМП")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.orange)
                        Text(formatPaceOrSpeed(meters: activity.distanceMeters, seconds: activity.movingTime))
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                    }
                }
                .padding(14)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 250, height: 444)
    }
    
    // MARK: - Logic and Image Generation
    
    private func backgroundGradient() -> some View {
        Group {
            switch theme {
            case .dark:
                Color(red: 0.08, green: 0.08, blue: 0.08)
            case .light:
                Color(red: 0.96, green: 0.96, blue: 0.96)
            case .gradient:
                LinearGradient(
                    colors: [Color.orange.opacity(0.3), Color.purple.opacity(0.2), Color(red: 0.08, green: 0.08, blue: 0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    private func loadMapSnapshot() async {
        isGeneratingMap = true
        // Set dimensions for high-res map based on aspect ratio
        let size = format == .square ? CGSize(width: 1024, height: 1024) : CGSize(width: 1080, height: 1920)
        let isDark = theme != .light
        mapImage = await generateMapSnapshot(for: activity, size: size, darkTheme: isDark)
        isGeneratingMap = false
    }
    
    private func generateMapSnapshot(for activity: Activity, size: CGSize, darkTheme: Bool) async -> UIImage? {
        let polyline = activity.encodedPolyline ?? ""
        let coords = PolylineEncoder.decode(polyline: polyline)
        guard !coords.isEmpty else { return nil }
        
        let options = MKMapSnapshotter.Options()
        options.size = size
        options.mapType = .standard
        
        var minLat = 90.0
        var maxLat = -90.0
        var minLng = 180.0
        var maxLng = -180.0
        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude)
            maxLng = max(maxLng, c.longitude)
        }
        
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0, longitude: (minLng + maxLng) / 2.0)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.45 + 0.002, longitudeDelta: (maxLng - minLng) * 1.45 + 0.002)
        options.region = MKCoordinateRegion(center: center, span: span)
        
        options.traitCollection = UITraitCollection(userInterfaceStyle: darkTheme ? .dark : .light)
        
        let snapshotter = MKMapSnapshotter(options: options)
        do {
            let snapshot = try await snapshotter.start()
            let baseImage = snapshot.image
            
            UIGraphicsBeginImageContextWithOptions(baseImage.size, true, baseImage.scale)
            baseImage.draw(at: .zero)
            
            if let context = UIGraphicsGetCurrentContext() {
                context.setLineCap(.round)
                context.setLineJoin(.round)
                // Select stroke colors based on theme
                let strokeColor = darkTheme ? UIColor.orange : UIColor(red: 0.95, green: 0.35, blue: 0.05, alpha: 1.0)
                context.setStrokeColor(strokeColor.cgColor)
                // Draw dynamic lines based on zoom
                context.setLineWidth(size.width / 130.0) 
                
                context.beginPath()
                let firstPoint = snapshot.point(for: coords[0])
                context.move(to: firstPoint)
                for i in 1..<coords.count {
                    let p = snapshot.point(for: coords[i])
                    context.addLine(to: p)
                }
                context.strokePath()
            }
            
            let finalImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return finalImage
        } catch {
            print("Failed map snapshot: \(error)")
            return nil
        }
    }
    
    // Generates final high-res 1080p image using SwiftUI ImageRenderer
    @MainActor
    private func renderFinalImage() -> UIImage? {
        guard let mapImg = mapImage else { return nil }
        
        // Define high-res size
        let finalSize = format == .square ? CGSize(width: 1080, height: 1080) : CGSize(width: 1080, height: 1920)
        
        // Create full resolution view matching size
        let renderView = ZStack {
            backgroundGradient()
            
            // Map
            Image(uiImage: mapImg)
                .resizable()
                .scaledToFill()
                .frame(width: finalSize.width, height: finalSize.height)
                .opacity(theme == .light ? 0.75 : 0.55)
            
            // Bottom overlay
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.black.opacity(0.9), Color.black.opacity(0.45), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: finalSize.height * 0.45)
            }
            
            if format == .square {
                // Square high-res layout
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(sportEmojiAndName())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.orange)
                            Text(formatDate(activity.startDate))
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
                    
                    HStack(alignment: .bottom, spacing: 60) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ДИСТАНЦИЯ")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                            Text(formatDistance(activity.distanceMeters))
                                .font(.system(size: 54, weight: .black))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ВРЕМЯ")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                            Text(formatTime(activity.movingTime))
                                .font(.system(size: 54, weight: .black))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("СРЕДНИЙ ТЕМП")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                            Text(formatPaceOrSpeed(meters: activity.distanceMeters, seconds: activity.movingTime))
                                .font(.system(size: 54, weight: .black))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(54)
                }
            } else {
                // Stories high-res layout
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("TezDav")
                            .font(.system(size: 44, weight: .black))
                            .italic()
                            .foregroundColor(.orange)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(sportEmojiAndName())
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.orange)
                            Text(formatDate(activity.startDate))
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(48)
                    .padding(.top, 48)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 40) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ДИСТАНЦИЯ")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.orange)
                            Text(formatDistance(activity.distanceMeters))
                                .font(.system(size: 74, weight: .black))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ВРЕМЯ ДВИЖЕНИЯ")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.orange)
                            Text(formatTime(activity.movingTime))
                                .font(.system(size: 74, weight: .black))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("СРЕДНИЙ ТЕМП")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.orange)
                            Text(formatPaceOrSpeed(meters: activity.distanceMeters, seconds: activity.movingTime))
                                .font(.system(size: 74, weight: .black))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(54)
                    .padding(.bottom, 60)
                }
            }
        }
        .frame(width: finalSize.width, height: finalSize.height)
        
        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 1.0
        return renderer.uiImage
    }
    
    private func shareCard() async {
        isSharing = true
        if let finalImage = await MainActor.run(body: { renderFinalImage() }) {
            exportItem = finalImage
        }
        isSharing = false
    }
    
    private func saveToPhotos() async {
        if let finalImage = await MainActor.run(body: { renderFinalImage() }) {
            UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
            showSaveSuccess = true
        }
    }
    
    // MARK: - Format Helpers
    
    private func sportEmojiAndName() -> String {
        switch activity.sportType {
        case "Run": return "🏃‍♂️ БЕГ"
        case "Ride": return "🚴‍♂️ ВЕЛОСИПЕД"
        case "Walk": return "🚶‍♂️ ХОДЬБА"
        case "Swim": return "🏊‍♂️ ПЛАВАНИЕ"
        case "Hike": return "🥾 ХАЙКИНГ"
        default: return "💪 АКТИВНОСТЬ"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = Locale(identifier: "ru_RU")
        return df.string(from: date).uppercased()
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let divider = isMetric ? 1000.0 : 1609.34
        let unit = isMetric ? "км" : "миль"
        return String(format: "%.2f %@", meters / divider, unit)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
    
    private func formatPaceOrSpeed(meters: Double, seconds: Double) -> String {
        guard meters > 0 && seconds > 0 else { return isMetric ? "0:00 /км" : "0:00 /милю" }
        
        if activity.sportType == "Ride" {
            // Speed km/h or mph
            let distanceInUnits = meters / (isMetric ? 1000.0 : 1609.34)
            let hours = seconds / 3600.0
            let speed = distanceInUnits / hours
            let unit = isMetric ? "км/ч" : "миль/ч"
            return String(format: "%.1f %@", speed, unit)
        } else {
            // Pace minutes per km or per mile
            let distanceInUnits = meters / (isMetric ? 1000.0 : 1609.34)
            let paceSeconds = seconds / distanceInUnits
            let paceMinutes = Int(paceSeconds) / 60
            let paceRemSeconds = Int(paceSeconds) % 60
            let unit = isMetric ? "/км" : "/милю"
            return String(format: "%d:%02d %@", paceMinutes, paceRemSeconds, unit)
        }
    }
}
