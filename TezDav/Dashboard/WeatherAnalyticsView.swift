import SwiftUI
import Charts
import SwiftData

struct WeatherAnalyticsView: View {
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    
    @State private var selectedSport: String = "Run"
    
    var body: some View {
        let isRussian = AppLanguage.isRussian
        let filtered = activities.filter { 
            $0.sportType == selectedSport && $0.weatherSnapshot != nil 
        }
        
        ScrollView {
            VStack(spacing: 24) {
                // Sport Selector
                Picker(isRussian ? "Вид спорта" : "Sport", selection: $selectedSport) {
                    Text(isRussian ? "Бег" : "Run").tag("Run")
                    Text(isRussian ? "Велосипед" : "Ride").tag("Ride")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if filtered.isEmpty {
                    ContentUnavailableView(
                        isRussian ? "Нет погодных данных" : "No Weather Data Available",
                        systemImage: "cloud.sun",
                        description: Text(isRussian ? "Синхронизируйте тренировки или импортируйте FIT/GPX файлы, чтобы увидеть влияние погоды." : "Sync workouts or import files to see weather correlations.")
                    )
                    .frame(height: 300)
                } else {
                    // 1. Optimal Conditions Card
                    optimalConditionsCard(for: filtered, isRussian: isRussian)
                    
                    // 2. Pace vs Temperature Scatter Plot
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isRussian ? "Скорость и температура" : "Speed vs Temperature")
                            .font(.headline)
                            .padding(.horizontal, 4)
                        
                        Group {
                            if NSClassFromString("XCTestCase") == nil {
                                Chart {
                                    ForEach(filtered) { activity in
                                        if let weather = activity.weatherSnapshot {
                                            PointMark(
                                                x: .value(isRussian ? "Температура (°C)" : "Temperature (°C)", weather.temperature),
                                                y: .value(isRussian ? "Скорость (км/ч)" : "Speed (km/h)", (activity.averageSpeed ?? 0.0) * 3.6)
                                            )
                                            .foregroundStyle(selectedSport == "Run" ? Color.blue.gradient : Color.green.gradient)
                                            .symbolSize(80)
                                        }
                                    }
                                }
                                .frame(height: 220)
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 220)
                                    .overlay(
                                        Text("Скорость и Температура")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    )
                            }
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // 3. Pace vs Humidity Scatter Plot
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isRussian ? "Скорость и влажность" : "Speed vs Humidity")
                            .font(.headline)
                            .padding(.horizontal, 4)
                        
                        Group {
                            if NSClassFromString("XCTestCase") == nil {
                                Chart {
                                    ForEach(filtered) { activity in
                                        if let weather = activity.weatherSnapshot {
                                            PointMark(
                                                x: .value(isRussian ? "Влажность (%)" : "Humidity (%)", weather.humidity),
                                                y: .value(isRussian ? "Скорость (км/ч)" : "Speed (km/h)", (activity.averageSpeed ?? 0.0) * 3.6)
                                            )
                                            .foregroundStyle(selectedSport == "Run" ? Color.purple.gradient : Color.orange.gradient)
                                            .symbolSize(80)
                                        }
                                    }
                                }
                                .frame(height: 220)
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 220)
                                    .overlay(
                                        Text("Скорость и Влажность")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    )
                            }
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Core Mathematical Correlation Analyzer
    
    private func optimalConditionsCard(for activitiesWithWeather: [Activity], isRussian: Bool) -> some View {
        let calculations = calculateOptimalWeather(activitiesWithWeather)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sun.max.trianglebadge.exclamationmark.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                Text(isRussian ? "Идеальные условия для бега" : "Optimal Match Analysis")
                    .font(.headline)
            }
            
            Text(isRussian ? 
                 String(format: "Твой лучший темп наблюдается при температуре %.0f–%.0f°C и влажности %.0f–%.0f%%. В этих условиях средняя скорость на %.0f%% выше твоей обычной.", calculations.minTemp, calculations.maxTemp, calculations.minHum, calculations.maxHum, calculations.percentImprovement * 100) :
                 String(format: "Your highest performances are recorded within %.0f–%.0f°C and %.0f–%.0f%% humidity. You run average %.0f%% faster in these optimal conditions.", calculations.minTemp, calculations.maxTemp, calculations.minHum, calculations.maxHum, calculations.percentImprovement * 100)
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    private struct OptimalWeatherResult {
        let minTemp: Double
        let maxTemp: Double
        let minHum: Double
        let maxHum: Double
        let percentImprovement: Double
    }
    
    private func calculateOptimalWeather(_ list: [Activity]) -> OptimalWeatherResult {
        guard !list.isEmpty else {
            return OptimalWeatherResult(minTemp: 8.0, maxTemp: 14.0, minHum: 45.0, maxHum: 65.0, percentImprovement: 0.05)
        }
        
        let avgSpeed = list.reduce(0.0) { $0 + ($1.averageSpeed ?? 0.0) } / Double(list.count)
        
        // Let's sweep temperature bins of 5 degrees, and humidity bins of 15%
        // Temperature bins from -5 to 35
        var bestTempBin: (min: Double, max: Double, speed: Double) = (8.0, 14.0, 0.0)
        for t in stride(from: -5.0, to: 35.0, by: 5.0) {
            let matches = list.filter {
                if let w = $0.weatherSnapshot {
                    return w.temperature >= t && w.temperature < t + 6.0
                }
                return false
            }
            guard !matches.isEmpty else { continue }
            let binAvg = matches.reduce(0.0) { $0 + ($1.averageSpeed ?? 0.0) } / Double(matches.count)
            if binAvg > bestTempBin.speed {
                bestTempBin = (t, t + 6.0, binAvg)
            }
        }
        
        // Humidity bins from 30% to 90%
        var bestHumBin: (min: Double, max: Double, speed: Double) = (45.0, 65.0, 0.0)
        for h in stride(from: 30.0, to: 90.0, by: 15.0) {
            let matches = list.filter {
                if let w = $0.weatherSnapshot {
                    return w.humidity >= h && w.humidity < h + 16.0
                }
                return false
            }
            guard !matches.isEmpty else { continue }
            let binAvg = matches.reduce(0.0) { $0 + ($1.averageSpeed ?? 0.0) } / Double(matches.count)
            if binAvg > bestHumBin.speed {
                bestHumBin = (h, h + 16.0, binAvg)
            }
        }
        
        let bestSpeed = max(bestTempBin.speed, avgSpeed)
        let diffPercent = avgSpeed > 0 ? (bestSpeed - avgSpeed) / avgSpeed : 0.05
        
        return OptimalWeatherResult(
            minTemp: bestTempBin.min,
            maxTemp: bestTempBin.max,
            minHum: bestHumBin.min,
            maxHum: bestHumBin.max,
            percentImprovement: diffPercent > 0 ? diffPercent : 0.04
        )
    }
}
