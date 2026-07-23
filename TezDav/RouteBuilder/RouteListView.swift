import SwiftUI
import SwiftData
import MapKit

struct RouteListView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \SavedRoute.createdAt, order: .reverse) private var allRoutes: [SavedRoute]
    
    @State private var showBuilder = false
    @State private var sortBy: SortOption = .date
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    
    enum SortOption {
        case date
        case distance
    }
    
    private var sortedRoutes: [SavedRoute] {
        switch sortBy {
        case .date:
            return allRoutes.sorted { $0.createdAt > $1.createdAt }
        case .distance:
            return allRoutes.sorted { $0.totalDistanceMeters > $1.totalDistanceMeters }
        }
    }
    
    @State private var selectedTabMode = 0 // 0 for Routes, 1 for Segments, 2 for Heatmap
    
    @ViewBuilder
    private var tabSelectorView: some View {
        GlassSegmentedControl(
            options: [0, 1, 2],
            selection: $selectedTabMode,
            title: { mode in
                mode == 0 ? "Маршруты" : (mode == 1 ? "Сегменты" : "Теплокарта")
            }
        )
        .padding(.horizontal, DesignTokens.Spacing.screen)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            if selectedTabMode == 0 {
                routesListSection
            } else if selectedTabMode == 1 {
                SegmentListView()
                    .padding(.top, 56)
            } else {
                PersonalHeatmapView()
                    .padding(.top, 56)
            }

            tabSelectorView
        }
        .navigationTitle("Карта")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if selectedTabMode == 0 {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Сортировка", selection: $sortBy) {
                            Label("По дате", systemImage: "calendar").tag(SortOption.date)
                            Label("По дистанции", systemImage: "arrow.triangle.pull").tag(SortOption.distance)
                        }
                    } label: {
                        Image(systemName: "arrow.up.and.down.text.horizontal")
                    }

                    Button {
                        HapticManager.trigger(.light)
                        showBuilder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showBuilder) {
            RouteBuilderView()
        }
    }
    
    @ViewBuilder
    private var routesListSection: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                UserAnnotation()

                ForEach(sortedRoutes) { route in
                    if route.routeCoordinates.count > 1 {
                        MapPolyline(coordinates: route.routeCoordinates)
                            .stroke(Color.accentPrimary, lineWidth: 4)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .preferredColorScheme(.dark)
            .ignoresSafeArea(edges: .bottom)

            if allRoutes.isEmpty {
                compactEmptyState
                .background(Color.backgroundPrimary.opacity(0.68), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.heroCard, style: .continuous))
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.bottom, 84)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(sortedRoutes) { route in
                            NavigationLink(destination: RouteDetailView(route: route)) {
                                RouteRowView(route: route)
                                    .frame(width: 320)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(route)
                                    try? modelContext.save()
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screen)
                    .padding(.bottom, DesignTokens.Spacing.md)
                }
                .frame(height: 250)
            }
        }
    }

    private var compactEmptyState: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "map")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 44, height: 44)
                .liquidGlassControl(shape: .circle, tint: .emerald)

            VStack(spacing: DesignTokens.Spacing.xxs) {
                Text("Нет маршрутов")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Text("Постройте маршрут и отправьте его на часы.")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Button {
                HapticManager.trigger(.light)
                showBuilder = true
            } label: {
                Label("Создать маршрут", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(LiquidGlassButtonStyle(prominent: true))
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: 320)
    }
    
    private func deleteRoutes(at offsets: IndexSet) {
        let sorted = sortedRoutes
        for index in offsets {
            let route = sorted[index]
            modelContext.delete(route)
        }
        try? modelContext.save()
    }
}

// Custom Row view for route card UI
struct RouteRowView: View {
    let route: SavedRoute
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Map snapshot preview
            RouteMapSnapshotView(
                coordinates: route.routeCoordinates,
                size: CGSize(width: UIScreen.main.bounds.width - 32, height: 140)
            )
            
            // Route details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(route.name)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Label(
                        route.sportType == "Run" ? "Бег" : "Вело",
                        systemImage: route.sportType == "Run" ? "figure.run" : "bicycle"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(route.sportType == "Run" ? Color.accentPrimary : Color.warning)
                }
                
                HStack(spacing: 16) {
                    Label(formatDistance(route.totalDistanceMeters), systemImage: "arrow.triangle.pull")
                        .font(.subheadline)
                        .foregroundColor(.textSecondaryReadable)
                    
                    Label(formatElevation(route.totalElevationGain), systemImage: "arrow.up.forward.circle")
                        .font(.subheadline)
                        .foregroundColor(.textSecondaryReadable)
                }
            }
            .padding()
        }
        .liquidGlassCard(cornerRadius: 16)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f км", meters / 1000.0)
        } else {
            return "\(Int(meters)) м"
        }
    }
    
    private func formatElevation(_ meters: Double) -> String {
        return String(format: "↑ %.0f м", meters)
    }
}
