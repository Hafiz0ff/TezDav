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
    
    @ViewBuilder
    private var tabSelectorView: some View {
        HStack(spacing: 6) {
            ForEach([0, 1, 2], id: \.self) { mode in
                Button {
                    HapticManager.trigger(.light)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        selectedTabMode = mode
                    }
                } label: {
                    Text(mode == 0 ? "Маршруты" : (mode == 1 ? "Сегменты" : "Теплокарта"))
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(selectedTabMode == mode ? Color.accentPrimary.opacity(0.12) : Color.white.opacity(0.04))
                        .foregroundColor(selectedTabMode == mode ? Color.accentPrimary : Color.textSecondaryReadable)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(selectedTabMode == mode ? Color.accentPrimary.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
            }
            
            if selectedTabMode == 0 {
                Spacer()
                
                Menu {
                    Picker("Сортировка", selection: $sortBy) {
                        Label("По дате", systemImage: "calendar").tag(SortOption.date)
                        Label("По дистанции", systemImage: "arrow.triangle.pull").tag(SortOption.distance)
                    }
                } label: {
                    Image(systemName: "arrow.up.and.down.text.horizontal")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.04))
                        .foregroundColor(Color.textSecondaryReadable)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                
                Button(action: {
                    HapticManager.trigger(.light)
                    showBuilder = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.04))
                        .foregroundColor(Color.textSecondaryReadable)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            tabSelectorView
            
            if selectedTabMode == 0 {
                routesListSection
            } else if selectedTabMode == 1 {
                SegmentListView()
            } else {
                PersonalHeatmapView()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showBuilder) {
            RouteBuilderView()
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
                        .foregroundStyle(Color.textPrimary)
                    
                    Text("Спланируйте свою следующую тренировку. Нарисуйте маршрут на карте, посмотрите перепады высот и отправьте на часы.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondaryReadable)
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
                            .background(Color.orange.gradient)
                            .cornerRadius(12)
                    }
                }
                .padding()
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedRoutes) { route in
                            NavigationLink(destination: RouteDetailView(route: route)) {
                                RouteRowView(route: route)
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
                    .padding(.horizontal, 14)
                    .padding(.bottom, 120)
                }
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
                        .foregroundColor(.textPrimary)
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
