import SwiftUI
import MapKit
import Charts
import SwiftData

struct RouteDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [UserSettings]
    
    let route: SavedRoute
    
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var showWatchSuccessAlert = false
    @State private var watchAlertMessage = ""
    
    @State private var googleCameraCenter: CLLocationCoordinate2D? = nil
    @State private var googleCameraZoom: Float? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Section 1: Route Map Preview
                ZStack(alignment: .bottomTrailing) {
                    TezDavMapView(
                        coordinates: route.routeCoordinates,
                        sportType: route.sportType,
                        showStartEndMarkers: true,
                        cameraCenter: $googleCameraCenter,
                        cameraZoom: $googleCameraZoom
                    )
                    .frame(height: 250)
                    .cornerRadius(16)
                    .shadow(radius: 4)
                    
                    // Sport badge
                    Text(route.sportType == "Run" ? "🏃‍♂️ Бег" : "🚴‍♀️ Вело")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(route.sportType == "Run" ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                        .foregroundColor(route.sportType == "Run" ? .green : .orange)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(route.sportType == "Run" ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                        )
                        .padding()
                }
                .padding(.horizontal)
                
                // Section 2: Statistics Grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Характеристики")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Дистанция", value: formatDistance(route.totalDistanceMeters), icon: "arrow.triangle.pull", color: .blue)
                        StatCard(title: "Набор высоты", value: formatElevation(route.totalElevationGain), icon: "arrow.up.forward.circle", color: .green)
                        StatCard(title: "Сброс высоты", value: formatElevation(route.totalElevationLoss), icon: "arrow.down.forward.circle", color: .secondary)
                        StatCard(title: "Расчетное время", value: formatTime(route.estimatedTimeSeconds), icon: "timer", color: .purple)
                    }
                    .padding(.horizontal)
                }
                
                // Section 3: Elevation Profile
                VStack(alignment: .leading, spacing: 12) {
                    Text("Профиль высот")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack {
                        if route.elevationProfile.isEmpty {
                            ContentUnavailableView("Профиль высот недоступен", systemImage: "chart.xyaxis.line")
                                .frame(height: 150)
                        } else {
                            let isMetric = settingsList.first?.isMetric ?? true
                            let distDivider = isMetric ? 1000.0 : 1609.344
                            let elevMultiplier = isMetric ? 1.0 : 3.28084
                            
                            Chart {
                                ForEach(route.elevationProfile) { pt in
                                    AreaMark(
                                        x: .value("Дистанция", pt.distance / distDivider),
                                        yStart: .value("Высота", minElevation),
                                        yEnd: .value("Высота", pt.elevation * elevMultiplier)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                (route.sportType == "Run" ? Color.green : Color.orange).opacity(0.4),
                                                (route.sportType == "Run" ? Color.green : Color.orange).opacity(0.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    
                                    LineMark(
                                        x: .value("Дистанция", pt.distance / distDivider),
                                        y: .value("Высота", pt.elevation * elevMultiplier)
                                    )
                                    .foregroundStyle(route.sportType == "Run" ? .green : .orange)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                }
                            }
                            .chartYScale(domain: minElevation...maxElevation)
                            .chartXAxis {
                                AxisMarks(values: .automatic) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    if let km = value.as(Double.self) {
                                        AxisValueLabel(String(format: isMetric ? "%.1f км" : "%.1f миль", km))
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(values: .automatic) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    if let elev = value.as(Double.self) {
                                        AxisValueLabel(String(format: isMetric ? "%.0f м" : "%.0f фт", elev))
                                    }
                                }
                            }
                            .frame(height: 150)
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                    .liquidGlassCard(cornerRadius: 16)
                    .padding(.horizontal)
                }
                
                // Section 4: Actions Block
                VStack(spacing: 12) {
                    if let gpxUrl = getGPXFileUrl() {
                        ShareLink(
                            item: gpxUrl,
                            preview: SharePreview(route.name, image: Image(systemName: "map.fill"))
                        ) {
                            Label("Экспортировать GPX", systemImage: "square.and.arrow.up")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue.gradient)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    
                    Button(action: sendToWatch) {
                        Label("Отправить на Apple Watch", systemImage: "applewatch")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.04))
                            .foregroundColor(.textPrimary)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            isEditing = true
                        }) {
                            Label("Изменить", systemImage: "pencil")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.04))
                                .foregroundColor(.textPrimary)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                        
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Label("Удалить", systemImage: "trash")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.12))
                                .foregroundColor(.red)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding()
            }
            .padding(.vertical)
        }
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AmbientBackgroundView())
        .onAppear {
            setupMapRegion()
        }
        .sheet(isPresented: $isEditing, onDismiss: {
            setupMapRegion() // refresh map in case coordinates changed
        }) {
            RouteBuilderView(routeToEdit: route)
        }
        .alert("Удалить маршрут", isPresented: $showDeleteConfirmation) {
            Button("Удалить", role: .destructive) {
                modelContext.delete(route)
                try? modelContext.save()
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы действительно хотите окончательно удалить этот маршрут?")
        }
        .alert("Синхронизация с Apple Watch", isPresented: $showWatchSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(watchAlertMessage)
        }
    }
    
    // MARK: - Helpers
    
    private func setupMapRegion() {
        guard !route.routeCoordinates.isEmpty else { return }
        
        var minLat = 90.0
        var maxLat = -90.0
        var minLon = 180.0
        var maxLon = -180.0
        
        for coord in route.routeCoordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        googleCameraCenter = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )
        
        let latDelta = maxLat - minLat
        let lonDelta = maxLon - minLon
        let maxDelta = max(latDelta, lonDelta)
        
        let zoom: Float
        if maxDelta > 0.5 {
            zoom = 10.0
        } else if maxDelta > 0.15 {
            zoom = 12.0
        } else if maxDelta > 0.05 {
            zoom = 13.0
        } else if maxDelta > 0.015 {
            zoom = 14.5
        } else {
            zoom = 15.5
        }
        googleCameraZoom = zoom
    }
    
    private var minElevation: Double {
        let isMetric = settingsList.first?.isMetric ?? true
        let multiplier = isMetric ? 1.0 : 3.28084
        let elevs = route.elevationProfile.map { $0.elevation * multiplier }
        let minVal = elevs.min() ?? 0.0
        return max(0.0, minVal - (isMetric ? 10.0 : 32.8))
    }
    
    private var maxElevation: Double {
        let isMetric = settingsList.first?.isMetric ?? true
        let multiplier = isMetric ? 1.0 : 3.28084
        let elevs = route.elevationProfile.map { $0.elevation * multiplier }
        return (elevs.max() ?? (isMetric ? 150.0 : 492.0)) + (isMetric ? 10.0 : 32.8)
    }
    
    private func getGPXFileUrl() -> URL? {
        let gpxString = ExportManager.exportRouteToGPX(route: route)
        let tempDir = FileManager.default.temporaryDirectory
        // Clean name for URL encoding safety
        let safeName = route.name.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
        let fileUrl = tempDir.appendingPathComponent("\(safeName).gpx")
        do {
            try gpxString.write(to: fileUrl, atomically: true, encoding: .utf8)
            return fileUrl
        } catch {
            print("Failed to write GPX: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func sendToWatch() {
        WatchConnectivityManager.shared.sendRoute(
            name: route.name,
            distance: route.totalDistanceMeters,
            elevation: route.totalElevationGain,
            sportType: route.sportType,
            coordinatesData: route.routeCoordinatesData
        )
        watchAlertMessage = "Маршрут '\(route.name)' отправлен на Apple Watch."
        showWatchSuccessAlert = true
    }
    
    // MARK: - Formatters
    
    private func formatDistance(_ meters: Double) -> String {
        let isMetric = settingsList.first?.isMetric ?? true
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
                return String(format: "%.0f фт", meters * 3.28084)
            }
        }
    }
    
    private func formatElevation(_ meters: Double) -> String {
        let isMetric = settingsList.first?.isMetric ?? true
        if isMetric {
            return String(format: "%.0f м", meters)
        } else {
            return String(format: "%.0f фт", meters * 3.28084)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "0м"
    }
}

// Reusable Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.textSecondaryReadable)
                    .bold()
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.textPrimary)
            }
            Spacer()
        }
        .padding()
        .liquidGlassCard(cornerRadius: 14)
    }
}
