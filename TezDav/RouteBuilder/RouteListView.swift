import SwiftUI
import SwiftData

struct RouteListView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \SavedRoute.createdAt, order: .reverse) private var allRoutes: [SavedRoute]
    
    @State private var showBuilder = false
    @State private var sortBy: SortOption = .date
    
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Режим", selection: $selectedTabMode) {
                    Text("Маршруты").tag(0)
                    Text("Сегменты").tag(1)
                    Text("Теплокарта").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))
                
                if selectedTabMode == 0 {
                    routesListSection
                } else if selectedTabMode == 1 {
                    SegmentListView()
                } else {
                    PersonalHeatmapView()
                }
            }
            .navigationTitle(selectedTabMode == 0 ? "Маршруты" : (selectedTabMode == 1 ? "Сегменты" : "Тепловая карта"))
            .toolbar {
                if selectedTabMode == 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                            Menu {
                                Picker("Сортировка", selection: $sortBy) {
                                    Label("По дате", systemImage: "calendar").tag(SortOption.date)
                                    Label("По дистанции", systemImage: "arrow.triangle.pull").tag(SortOption.distance)
                                }
                            } label: {
                                Image(systemName: "arrow.up.and.down.text.horizontal")
                            }
                            
                            Button(action: {
                                showBuilder = true
                            }) {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showBuilder) {
                RouteBuilderView()
            }
        }
    }
    
    @ViewBuilder
    private var routesListSection: some View {
        Group {
            if allRoutes.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "map")
                        .font(.system(size: 64))
                        .foregroundColor(.orange.opacity(0.8))
                        .padding()
                        .background(Circle().fill(Color.orange.opacity(0.1)))
                    
                    Text("Нет маршрутов")
                        .font(.title3)
                        .bold()
                    
                    Text("Спланируйте свою следующую тренировку. Нарисуйте маршрут на карте, посмотрите перепады высот и отправьте на часы.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        showBuilder = true
                    }) {
                        Text("Создать маршрут")
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                }
                .padding()
                Spacer()
            } else {
                List {
                    ForEach(sortedRoutes) { route in
                        NavigationLink(destination: RouteDetailView(route: route)) {
                            RouteRowView(route: route)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteRoutes)
                }
                .listStyle(.plain)
                .background(Color(.systemGroupedBackground))
            }
        }
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
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(route.sportType == "Run" ? "🏃‍♂️ Бег" : "🚴‍♀️ Вело")
                        .font(.caption)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(route.sportType == "Run" ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .foregroundColor(route.sportType == "Run" ? .green : .orange)
                        .cornerRadius(6)
                }
                
                HStack(spacing: 16) {
                    Label(formatDistance(route.totalDistanceMeters), systemImage: "arrow.triangle.pull")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Label(formatElevation(route.totalElevationGain), systemImage: "arrow.up.forward.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
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
