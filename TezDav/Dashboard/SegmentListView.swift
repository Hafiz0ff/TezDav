import SwiftUI
import SwiftData

struct SegmentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var segments: [Segment]
    @Query private var userSettings: [UserSettings]
    
    @State private var sportFilter: String = "All" // "All", "Run", "Ride"
    @State private var searchText: String = ""
    @State private var sortBy: SortOption = .name
    
    enum SortOption {
        case name
        case distance
        case grade
    }
    
    private var activeUserSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }
    
    private var filteredSegments: [Segment] {
        var result = segments
        
        // Search
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Sport Filter
        if sportFilter != "All" {
            result = result.filter { $0.sportType == sportFilter }
        }
        
        // Sorting
        switch sortBy {
        case .name:
            result.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .distance:
            result.sort { $0.distanceMeters > $1.distanceMeters }
        case .grade:
            result.sort { $0.averageGrade > $1.averageGrade }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filters Header
            VStack(spacing: 12) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Поиск сегментов...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                
                HStack(spacing: 12) {
                    // Sport Filter Picker
                    Picker("Спорт", selection: $sportFilter) {
                        Text("Все").tag("All")
                        Text("Бег").tag("Run")
                        Text("Вело").tag("Ride")
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                    
                    Spacer()
                    
                    // Sort Menu
                    Menu {
                        Picker("Сортировка", selection: $sortBy) {
                            Label("По имени", systemImage: "textformat").tag(SortOption.name)
                            Label("По дистанции", systemImage: "arrow.triangle.pull").tag(SortOption.distance)
                            Label("По уклону", systemImage: "arrow.up.forward").tag(SortOption.grade)
                        }
                    } label: {
                        HStack {
                            Text("Сортировка")
                                .font(.subheadline)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 3)
            
            // List content
            if filteredSegments.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange.opacity(0.3))
                    Text("Сегменты не найдены")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Попробуйте изменить параметры поиска или фильтры")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredSegments) { segment in
                        NavigationLink(destination: SegmentDetailView(segment: segment)) {
                            SegmentRowView(segment: segment, isMetric: activeUserSettings.isMetric)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .background(Color(.systemGroupedBackground))
            }
        }
        .onAppear {
            if segments.isEmpty {
                SegmentMatcher.seedSegments(context: modelContext)
            }
        }
    }
}

struct SegmentRowView: View {
    let segment: Segment
    let isMetric: Bool
    
    private var prEffort: SegmentEffort? {
        segment.efforts
            .filter { !$0.isMock && $0.athleteName == "Вы" }
            .min(by: { $0.elapsedTime < $1.elapsedTime })
    }
    
    private var userAttemptsCount: Int {
        segment.efforts.filter { !$0.isMock && $0.athleteName == "Вы" }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(segment.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        Text(segment.sportType == "Run" ? "🏃‍♂️ Бег" : "🚴‍♀️ Вело")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(segment.sportType == "Run" ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                            .foregroundColor(segment.sportType == "Run" ? .green : .orange)
                            .cornerRadius(4)
                        
                        Text(formatDistance(segment.distanceMeters))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.1f%% уклон", segment.averageGrade))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // PR display
                if let pr = prEffort {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ЛР")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.orange)
                        Text(formatDuration(pr.elapsedTime))
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.primary)
                    }
                } else {
                    Text("Нет попыток")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
            
            if userAttemptsCount > 0 {
                Divider()
                HStack {
                    Label("\(userAttemptsCount) попыток", systemImage: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let bestRank = calculateRank() {
                        Label("\(bestRank) место на лидерборде", systemImage: "crown.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
    
    private func calculateRank() -> Int? {
        let allEfforts = segment.efforts.sorted(by: { $0.elapsedTime < $1.elapsedTime })
        guard let myBest = prEffort else { return nil }
        
        // Group by athlete, keep best effort per athlete to build the leaderboard
        var uniqueAthletes: [String: SegmentEffort] = [:]
        for effort in allEfforts {
            if let existing = uniqueAthletes[effort.athleteName] {
                if effort.elapsedTime < existing.elapsedTime {
                    uniqueAthletes[effort.athleteName] = effort
                }
            } else {
                uniqueAthletes[effort.athleteName] = effort
            }
        }
        
        let leaderboard = uniqueAthletes.values.sorted(by: { $0.elapsedTime < $1.elapsedTime })
        if let idx = leaderboard.firstIndex(where: { $0.athleteName == "Вы" }) {
            return idx + 1
        }
        return nil
    }
    
    private func formatDistance(_ meters: Double) -> String {
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
}
