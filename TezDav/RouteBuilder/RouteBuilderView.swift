import SwiftUI
import MapKit
import SwiftData

struct WaypointMarker: Identifiable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
}

struct RouteBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let routeToEdit: SavedRoute?
    
    @StateObject private var routeEngine = RouteEngine()
    @State private var routeName: String = ""
    @State private var selectedSport: String = "Run"
    
    // UI state
    @State private var selectedWaypointIndex: Int? = nil
    @State private var showDeleteWaypointAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Map state
    @State private var googleCameraCenter: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 38.5598, longitude: 68.7870)
    @State private var googleCameraZoom: Float? = 12.0
    
    @Query private var userSettingsList: [UserSettings]
    private var userSettings: UserSettings? {
        userSettingsList.first
    }
    
    private var runningPace: Double {
        userSettings?.runningThresholdPaceSecondsPerKm ?? 300.0 // 5:00 / km default
    }
    
    private var cyclingPace: Double {
        let ftp = userSettings?.cyclingFTP ?? 250.0
        let speedKmh = 15.0 + (ftp / 25.0) // e.g. 250 FTP = 25 km/h
        return 3600.0 / speedKmh
    }
    
    private var currentPace: Double {
        if selectedSport == "Run" {
            return runningPace
        } else {
            return cyclingPace
        }
    }
    
    private var routeLineGradient: Gradient {
        if selectedSport == "Run" {
            return Gradient(colors: [.blue, .green])
        } else {
            return Gradient(colors: [.blue, .orange])
        }
    }
    
    private func waypointColor(for index: Int, totalCount: Int) -> Color {
        if index == 0 {
            return .green
        } else if index == totalCount - 1 {
            return .red
        } else {
            return .black
        }
    }
    
    private var saveButtonColor: Color {
        if routeName.isEmpty || routeEngine.waypoints.count < 2 {
            return Color.orange.opacity(0.5)
        } else {
            return Color.orange
        }
    }
    
    private var waypointMarkers: [WaypointMarker] {
        routeEngine.waypoints.enumerated().map { WaypointMarker(id: $0.offset, coordinate: $0.element) }
    }
    
    init(routeToEdit: SavedRoute? = nil) {
        self.routeToEdit = routeToEdit
    }
    
    private var mapView: some View {
        GoogleMapView(
            coordinates: routeEngine.fullRouteCoordinates,
            waypoints: routeEngine.waypoints,
            sportType: selectedSport,
            onTap: { coordinate in
                Task {
                    await routeEngine.addWaypoint(coordinate)
                }
            },
            onWaypointTap: { index in
                selectedWaypointIndex = index
                showDeleteWaypointAlert = true
            },
            cameraCenter: $googleCameraCenter,
            cameraZoom: $googleCameraZoom
        )
    }
    
    private var topOverlayPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TextField("Название маршрута", text: $routeName)
                    .font(.headline)
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .foregroundColor(.textPrimary)
                
                HStack(spacing: 4) {
                    ForEach(["Run", "Ride"], id: \.self) { sport in
                        Button {
                            HapticManager.trigger(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedSport = sport
                                routeEngine.sportType = sport
                            }
                        } label: {
                            Text(sport == "Run" ? "Бег" : "Вело")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedSport == sport ? Color.accentPrimary.opacity(0.12) : Color.white.opacity(0.04))
                                .foregroundColor(selectedSport == sport ? Color.accentPrimary : Color.textSecondaryReadable)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(selectedSport == sport ? Color.accentPrimary.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                }
                .frame(width: 120)
            }
            
            if routeEngine.isCalculating {
                HStack {
                    ProgressView()
                        .padding(.trailing, 6)
                    Text("Прокладываем маршрут...")
                        .font(.caption)
                        .foregroundColor(.textSecondaryReadable)
                }
            }
        }
        .padding()
        .liquidGlassCard(cornerRadius: 16)
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private var bottomStatsPanel: some View {
        VStack(spacing: 16) {
            // Metric Grid
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ДИСТАНЦИЯ")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.textSecondaryReadable)
                    Text(formatDistance(routeEngine.totalDistance))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .contentTransition(.numericText())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("НАБОР ВЫСОТЫ")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.textSecondaryReadable)
                    Text(formatElevation(routeEngine.totalElevationGain))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .contentTransition(.numericText())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ВРЕМЯ (~)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.textSecondaryReadable)
                    Text(formatTime(routeEngine.estimatedTime(averagePaceSecPerKm: currentPace)))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .contentTransition(.numericText())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            // Control Buttons
            HStack(spacing: 12) {
                Button(action: {
                    routeEngine.undo()
                }) {
                    Label("Назад", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.04))
                        .foregroundColor(routeEngine.waypoints.isEmpty ? .textTertiaryReadable : .textPrimary)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .disabled(routeEngine.waypoints.isEmpty)
                
                Button(action: {
                    routeEngine.clearAll()
                }) {
                    Label("Очистить", systemImage: "trash")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(routeEngine.waypoints.isEmpty ? 0.04 : 0.12))
                        .foregroundColor(routeEngine.waypoints.isEmpty ? .textTertiaryReadable : .red)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(routeEngine.waypoints.isEmpty ? Color.white.opacity(0.08) : Color.red.opacity(0.3), lineWidth: 1)
                        )
                }
                .disabled(routeEngine.waypoints.isEmpty)
                
                Button(action: saveRoute) {
                    Text("Сохранить")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                if routeName.isEmpty || routeEngine.waypoints.count < 2 {
                                    Color.orange.opacity(0.3)
                                } else {
                                    Color.orange
                                }
                            }
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(routeName.isEmpty || routeEngine.waypoints.count < 2)
            }
        }
        .padding()
        .liquidGlassCard(cornerRadius: 16)
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapView
                    .edgesIgnoringSafeArea(.bottom)
                
                // Overlay Panels (Route Name + Settings + Stats)
                VStack(spacing: 0) {
                    topOverlayPanel
                    
                    Spacer()
                    
                    bottomStatsPanel
                }
            }
            .navigationTitle("Новый маршрут")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let route = routeToEdit {
                    routeName = route.name
                    selectedSport = route.sportType
                    routeEngine.loadFromRoute(route)
                    
                    // Center map on route
                    if let firstCoord = route.waypoints.first {
                        googleCameraCenter = firstCoord
                        googleCameraZoom = 14.0
                    }
                }
            }
            .alert("Удалить точку", isPresented: $showDeleteWaypointAlert) {
                Button("Удалить", role: .destructive) {
                    if let index = selectedWaypointIndex {
                        Task {
                            await routeEngine.removeWaypoint(at: index)
                        }
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                if let index = selectedWaypointIndex {
                    Text("Вы уверены, что хотите удалить точку #\(index + 1) из маршрута?")
                }
            }
            .alert("Ошибка", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Save Logic
    
    private func saveRoute() {
        guard !routeName.isEmpty else { return }
        guard routeEngine.waypoints.count >= 2 else {
            errorMessage = "Маршрут должен содержать как минимум 2 точки."
            showErrorAlert = true
            return
        }
        
        let context = modelContext
        
        if let existing = routeToEdit {
            existing.name = routeName
            existing.sportType = selectedSport
            existing.totalDistanceMeters = routeEngine.totalDistance
            existing.totalElevationGain = routeEngine.totalElevationGain
            existing.totalElevationLoss = routeEngine.totalElevationLoss
            existing.estimatedTimeSeconds = routeEngine.estimatedTime(averagePaceSecPerKm: currentPace)
            
            existing.waypoints = routeEngine.waypoints
            existing.routeCoordinates = routeEngine.fullRouteCoordinates
            existing.elevationProfile = routeEngine.elevationProfile
        } else {
            let newRoute = SavedRoute(
                name: routeName,
                sportType: selectedSport,
                totalDistanceMeters: routeEngine.totalDistance,
                totalElevationGain: routeEngine.totalElevationGain,
                totalElevationLoss: routeEngine.totalElevationLoss,
                estimatedTimeSeconds: routeEngine.estimatedTime(averagePaceSecPerKm: currentPace)
            )
            
            newRoute.waypoints = routeEngine.waypoints
            newRoute.routeCoordinates = routeEngine.fullRouteCoordinates
            newRoute.elevationProfile = routeEngine.elevationProfile
            
            context.insert(newRoute)
        }
        
        do {
            try context.save()
            dismiss()
        } catch {
            errorMessage = "Не удалось сохранить маршрут: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    // MARK: - Formatters
    
    private func formatDistance(_ meters: Double) -> String {
        let isMetric = userSettings?.isMetric ?? true
        if isMetric {
            if meters >= 1000 {
                return String(format: "%.2f км", meters / 1000.0)
            } else {
                return "\(Int(meters)) м"
            }
        } else {
            let miles = meters / 1609.344
            if miles >= 0.1 {
                return String(format: "%.2f mi", miles)
            } else {
                return String(format: "%.0f ft", meters * 3.28084)
            }
        }
    }
    
    private func formatElevation(_ meters: Double) -> String {
        let isMetric = userSettings?.isMetric ?? true
        if isMetric {
            return String(format: "↑ %.0f м", meters)
        } else {
            return String(format: "↑ %.0f ft", meters * 3.28084)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? "0:00"
    }
}
