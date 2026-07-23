import SwiftUI
import MapKit
import Charts
import SwiftData

struct SegmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userSettings: [UserSettings]
    
    let segment: Segment
    
    @State private var cameraCenter: CLLocationCoordinate2D? = nil
    @State private var cameraZoom: Float? = nil
    @State private var leaderboardTab = 0 // 0 = Все результаты, 1 = Мои попытки
    
    private var activeUserSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }
    
    private var elevationProfile: [ElevationPoint] {
        let count = 10
        let step = segment.distanceMeters / Double(count - 1)
        var points: [ElevationPoint] = []
        
        let startElevation: Double
        if segment.name.contains("Рудаки") {
            startElevation = 720.0
        } else if segment.name.contains("амфитеатру") {
            startElevation = 730.0
        } else if segment.name.contains("Сарез") {
            startElevation = 710.0
        } else if segment.name.contains("Варзоб") {
            startElevation = 750.0
        } else {
            startElevation = 700.0
        }
        
        for i in 0..<count {
            let dist = Double(i) * step
            let t = Double(i) / Double(count - 1)
            let sineWave = sin(t * .pi * 2.0) * (segment.elevationGain * 0.15)
            let elev = startElevation + (segment.elevationGain * t) + sineWave
            points.append(ElevationPoint(distance: dist, elevation: elev))
        }
        return points
    }
    
    // Overall leaderboard: unique athlete efforts, showing each athlete's best effort
    private var overallLeaderboard: [SegmentEffort] {
        let allEfforts = segment.efforts.sorted(by: { $0.elapsedTime < $1.elapsedTime })
        var bestEfforts: [String: SegmentEffort] = [:]
        
        for effort in allEfforts {
            if let existing = bestEfforts[effort.athleteName] {
                if effort.elapsedTime < existing.elapsedTime {
                    bestEfforts[effort.athleteName] = effort
                }
            } else {
                bestEfforts[effort.athleteName] = effort
            }
        }
        
        return bestEfforts.values.sorted(by: { $0.elapsedTime < $1.elapsedTime })
    }
    
    // User's attempts only, sorted by date or fastest
    private var myAttempts: [SegmentEffort] {
        segment.efforts
            .filter { !$0.isMock && $0.athleteName == "Вы" }
            .sorted(by: { $0.elapsedTime < $1.elapsedTime })
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Section 1: Map
                ZStack(alignment: .bottomTrailing) {
                    TezDavMapView(
                        coordinates: segment.coordinates,
                        sportType: segment.sportType,
                        showStartEndMarkers: true,
                        cameraCenter: $cameraCenter,
                        cameraZoom: $cameraZoom
                    )
                    .frame(height: 220)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                    
                    // Sport Type Badge
                    Text(segment.sportType == "Run" ? "🏃‍♂️ Бег" : "🚴‍♀️ Вело")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding([.bottom, .trailing], 10)
                }
                
                // Section 2: Metrics cards
                HStack(spacing: 12) {
                    metricCard(title: "Расстояние", value: formatDistance(segment.distanceMeters), systemImage: "arrow.triangle.pull")
                    metricCard(title: "Набор высоты", value: formatElevation(segment.elevationGain), systemImage: "arrow.up.forward.circle")
                    metricCard(title: "Средний уклон", value: String(format: "%.1f%%", segment.averageGrade), systemImage: "percent")
                }
                
                // Section 3: Elevation Profile
                VStack(alignment: .leading, spacing: 8) {
                    Text("Профиль высот")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Chart(elevationProfile) { pt in
                        AreaMark(
                            x: .value("Дистанция", pt.distance),
                            y: .value("Высота", pt.elevation)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [Color.orange.opacity(0.6), Color.orange.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        
                        LineMark(
                            x: .value("Дистанция", pt.distance),
                            y: .value("Высота", pt.elevation)
                        )
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                    }
                    .frame(height: 120)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let dist = value.as(Double.self) {
                                    Text(formatDistance(dist))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let elev = value.as(Double.self) {
                                    Text(formatElevation(elev))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
                
                // Section 4: Leaderboard
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Режим таблицы результатов", selection: $leaderboardTab) {
                        Text("Все результаты").tag(0)
                        Text("Мои попытки").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)
                    
                    let effortsToDisplay = leaderboardTab == 0 ? overallLeaderboard : myAttempts
                    
                    if effortsToDisplay.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Нет результатов")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        VStack(spacing: 0) {
                            // Headers
                            HStack {
                                Text("Ранг").frame(width: 45, alignment: .leading)
                                Text("Имя").frame(maxWidth: .infinity, alignment: .leading)
                                Text("Параметры").frame(width: 100, alignment: .trailing)
                                Text("Время").frame(width: 70, alignment: .trailing)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                            .padding(.horizontal, 12)
                            
                            Divider()
                            
                            ForEach(Array(effortsToDisplay.enumerated()), id: \.element.id) { index, effort in
                                HStack {
                                    // Rank cell
                                    HStack {
                                        if leaderboardTab == 0 {
                                            if index == 0 {
                                                Image(systemName: "crown.fill")
                                                    .foregroundColor(.yellow)
                                            } else if index == 1 {
                                                Image(systemName: "medal.fill")
                                                    .foregroundColor(.gray)
                                            } else if index == 2 {
                                                Image(systemName: "medal.fill")
                                                    .foregroundColor(.brown)
                                            } else {
                                                Text("\(index + 1)")
                                                    .font(.subheadline.weight(.semibold))
                                            }
                                        } else {
                                            Text("\(index + 1)")
                                                .font(.subheadline.weight(.semibold))
                                        }
                                    }
                                    .frame(width: 45, alignment: .leading)
                                    
                                    // Athlete Name & Date
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(effort.athleteName)
                                            .font(.subheadline.weight(effort.athleteName == "Вы" ? .bold : .regular))
                                            .foregroundColor(effort.athleteName == "Вы" ? .orange : .primary)
                                        Text(effort.startDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    // Parameters (HR / Power / Speed)
                                    VStack(alignment: .trailing, spacing: 2) {
                                        if let hr = effort.averageHeartRate {
                                            Text(String(format: "❤️ %.0f уд/мин", hr))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        if let speed = effort.averageSpeed {
                                            Text(formatSpeedPace(speed))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 100, alignment: .trailing)
                                    
                                    // Time
                                    Text(formatDuration(effort.elapsedTime))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(effort.athleteName == "Вы" ? .orange : .primary)
                                        .frame(width: 70, alignment: .trailing)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(effort.athleteName == "Вы" ? Color.orange.opacity(0.06) : Color.clear)
                                .cornerRadius(8)
                                
                                if index < effortsToDisplay.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(segment.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Views
    private func metricCard(title: String, value: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.orange)
            
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Format Helpers
    private func formatDistance(_ meters: Double) -> String {
        let isMetric = activeUserSettings.isMetric
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
                return "\(Int(feet)) фт"
            }
        }
    }
    
    private func formatElevation(_ meters: Double) -> String {
        let isMetric = activeUserSettings.isMetric
        if isMetric {
            return String(format: "↑ %.0f м", meters)
        } else {
            return String(format: "↑ %.0f фт", meters * 3.28084)
        }
    }
    
    private func formatSpeedPace(_ speedMPS: Double) -> String {
        let isMetric = activeUserSettings.isMetric
        if segment.sportType == "Run" {
            // Pace formatting (MM:SS)
            guard speedMPS > 0 else { return "--:--" }
            let unitDist = isMetric ? 1000.0 : 1609.344
            let secPerUnit = unitDist / speedMPS
            let mins = Int(secPerUnit) / 60
            let secs = Int(secPerUnit) % 60
            let label = isMetric ? "/км" : "/миля"
            return String(format: "%d:%02d %@", mins, secs, label)
        } else {
            // Speed formatting
            let factor = isMetric ? 3.6 : 2.23694
            let unit = isMetric ? "км/ч" : "миль/ч"
            return String(format: "%.1f %@", speedMPS * factor, unit)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
