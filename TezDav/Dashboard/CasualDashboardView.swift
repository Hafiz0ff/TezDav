import SwiftUI
import SwiftData
import HealthKit

struct CasualDashboardView: View {
    let activities: [Activity]
    let settings: UserSettings
    
    @State private var stepsToday: Int = 0
    @State private var activeCaloriesToday: Int = 0
    
    private var activeDaysAndStreak: (activeDays: Set<Date>, currentStreak: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var activeDates = Set<Date>()
        
        for activity in activities {
            let day = calendar.startOfDay(for: activity.startDate)
            activeDates.insert(day)
        }
        
        // Calculate streak
        var streak = 0
        var checkDate = today
        
        if activeDates.contains(today) {
            streak = 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
            while activeDates.contains(checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            }
        } else {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if activeDates.contains(yesterday) {
                streak = 1
                checkDate = calendar.date(byAdding: .day, value: -2, to: today)!
                while activeDates.contains(checkDate) {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                }
            }
        }
        
        return (activeDates, streak)
    }
    
    private var weeklyActiveMinutes: Double {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return 0.0
        }
        let thisWeekActivities = activities.filter { $0.startDate >= startOfWeek }
        return thisWeekActivities.reduce(0.0) { sum, activity in
            let mins = Double(activity.activeMinutes ?? Int(activity.movingTime / 60.0))
            return sum + mins
        }
    }
    
    private var weeklyVolume: (distance: Double, hours: Double) {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return (0.0, 0.0)
        }
        let thisWeekActivities = activities.filter { $0.startDate >= startOfWeek }
        let meters = thisWeekActivities.reduce(0.0) { $0 + $1.distanceMeters }
        let seconds = thisWeekActivities.reduce(0.0) { $0 + $1.movingTime }
        
        let divisor = settings.isMetric ? 1000.0 : 1609.344
        return (meters / divisor, seconds / 3600.0)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Card 1: На этой неделе (Active Minutes & Progress Ring)
            weeklyProgressCard
            
            // Card 2: Активные дни (4-Week Grid & Streaks)
            activeDaysCard
            
            // Card 3: Сегодня (Steps & Telemetry)
            todayCard
            
            // Last workout brief if available
            if let lastActivity = activities.first {
                lastActivityBriefCard(lastActivity)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
        .onAppear {
            fetchSteps()
        }
    }
    
    private var weeklyProgressCard: some View {
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        let target = settings.targetWeeklyActiveMinutes
        let mins = weeklyActiveMinutes
        let pct = target > 0 ? min(1.0, mins / target) : 0.0
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isRussian ? "На этой неделе" : "This Week")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(isRussian ? "Активные минуты" : "Active Minutes")
                        .font(.title2.bold())
                }
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.15), lineWidth: 10)
                        .frame(width: 64, height: 64)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(pct))
                        .stroke(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(pct * 100))%")
                        .font(.subheadline.bold())
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("\(Int(mins)) \(isRussian ? "мин" : "min")")
                        .font(.title3.bold())
                        .foregroundStyle(Color.orange)
                    Text(isRussian ? "из \(Int(target)) мин (ВОЗ)" : "of \(Int(target)) min (WHO)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading) {
                    let unit = settings.isMetric ? (isRussian ? "км" : "km") : (isRussian ? "миль" : "mi")
                    Text(String(format: "%.1f %@", weeklyVolume.distance, unit))
                        .font(.title3.bold())
                    Text(isRussian ? "Расстояние" : "Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading) {
                    Text(String(format: "%.1f ч", weeklyVolume.hours))
                        .font(.title3.bold())
                    Text(isRussian ? "Время в движении" : "Moving Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10)
        )
    }
    
    private var activeDaysCard: some View {
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        let (activeDates, streak) = activeDaysAndStreak
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        // Build array of last 28 days ending today, aligned to weeks
        var daysList: [Date] = []
        for offset in (0..<28).reversed() {
            if let date = calendar.date(byAdding: .day, value: -offset, to: today) {
                daysList.append(calendar.startOfDay(for: date))
            }
        }
        
        let weekdaySymbols = isRussian ? ["П", "В", "С", "Ч", "П", "С", "В"] : ["M", "T", "W", "T", "F", "S", "S"]
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isRussian ? "Активность" : "Active Days")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(isRussian ? "Календарь занятий" : "Last 4 Weeks")
                        .font(.title2.bold())
                }
                Spacer()
                
                if streak > 0 {
                    HStack(spacing: 4) {
                        Text("🔥")
                        Text("\(streak) \(isRussian ? "дней" : "days")")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(12)
                }
            }
            
            // Grid of days
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { symbolIndex in
                        Text(weekdaySymbols[symbolIndex])
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(daysList, id: \.self) { date in
                        let isActive = activeDates.contains(date)
                        let isToday = date == today
                        
                        ZStack {
                            Circle()
                                .fill(isActive ? Color.green : (isToday ? Color.primary.opacity(0.1) : Color.primary.opacity(0.03)))
                                .frame(width: 32, height: 32)
                            
                            if isToday {
                                Circle()
                                    .stroke(isActive ? Color.green : Color.orange, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                            }
                            
                            let dayNum = calendar.component(.day, from: date)
                            Text("\(dayNum)")
                                .font(.caption2.bold())
                                .foregroundStyle(isActive ? Color.white : Color.primary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10)
        )
    }
    
    private var todayCard: some View {
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isRussian ? "Сегодня" : "Today")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(isRussian ? "Показатели движения" : "Daily Activity")
                    .font(.title2.bold())
            }
            
            HStack(spacing: 16) {
                // Steps Card
                HStack(spacing: 12) {
                    Image(systemName: "figure.walk")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .frame(width: 44, height: 44)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(stepsToday)")
                            .font(.title3.bold())
                        Text(isRussian ? "Шаги" : "Steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.primary.opacity(0.02))
                .cornerRadius(16)
                
                // Active Calories Card
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(activeCaloriesToday) ккал")
                            .font(.title3.bold())
                        Text(isRussian ? "Калории" : "Calories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.primary.opacity(0.02))
                .cornerRadius(16)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10)
        )
    }
    
    private func lastActivityBriefCard(_ activity: Activity) -> some View {
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        let isMetric = settings.isMetric
        let divisor = isMetric ? 1000.0 : 1609.344
        let unit = isMetric ? (isRussian ? " км" : " km") : (isRussian ? " миль" : " mi")
        let distStr = String(format: "%.2f%@", activity.distanceMeters / divisor, unit)
        
        let movingTimeMinutes = Int(activity.movingTime / 60)
        let timeStr = movingTimeMinutes >= 60 ? "\(movingTimeMinutes / 60) ч \(movingTimeMinutes % 60) м" : "\(movingTimeMinutes) мин"
        
        let calorieEstimate: Int = {
            if let steps = activity.stepsCount {
                return Int(Double(steps) * 0.045) // Approx kcal per step
            }
            let weight = settings.weightKg
            let distKm = activity.distanceMeters / 1000.0
            return Int(weight * distKm * 1.03) // Metabolic equation fallback
        }()
        
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isRussian ? "Последнее занятие" : "Last Activity")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(activity.name)
                    .font(.title3.bold())
                    .lineLimit(1)
            }
            
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: sportIcon(activity.sportType))
                        .foregroundStyle(.orange)
                    Text(activity.sportType)
                        .font(.subheadline.bold())
                }
                
                Text(distStr)
                    .font(.subheadline.bold())
                
                Text(timeStr)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(calorieEstimate) ккал")
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10)
        )
    }
    
    private func sportIcon(_ sportType: String) -> String {
        let lower = sportType.lowercased()
        if lower.contains("run") { return "figure.run" }
        if lower.contains("ride") || lower.contains("cycl") { return "bicycle" }
        if lower.contains("walk") || lower.contains("hike") { return "figure.walk" }
        if lower.contains("swim") { return "figure.pool.swim" }
        return "figure.mixed.cardio"
    }
    
    private func fetchSteps() {
        Task {
            let authorized = await HealthKitManager.shared.requestAuthorization()
            if authorized {
                let telemetry = await HealthKitManager.shared.fetchDailyTelemetry()
                await MainActor.run {
                    self.stepsToday = Int(telemetry.steps)
                    self.activeCaloriesToday = Int(telemetry.activeCalories)
                }
            }
        }
    }
}
