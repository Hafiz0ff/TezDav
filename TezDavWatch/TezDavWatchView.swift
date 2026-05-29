import SwiftUI

struct TezDavWatchView: View {
    @EnvironmentObject var viewModel: WatchViewModel
    
    var body: some View {
        TabView {
            // Screen 1: Dashboard Home (TSB and Recovery Score gauges)
            WatchHomeScreen()
            
            // Screen 2: Form (PMC breakdown: CTL, ATL, TSB)
            WatchFormScreen()
            
            // Screen 3: Weekly progress vs target goals
            WatchWeeklyProgressScreen()
            
            // Screen 4: Last Workout summary details
            WatchLastWorkoutScreen()
        }
        .tabViewStyle(.page)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Screen 1: Home Dashboard Screen
struct WatchHomeScreen: View {
    @EnvironmentObject var viewModel: WatchViewModel
    
    var body: some View {
        VStack(spacing: 6) {
            Text("Готовность")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                // Recovery Score gauge
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(.tertiary.opacity(0.3), lineWidth: 5)
                            .frame(width: 54, height: 54)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(Double(viewModel.snapshot.recoveryScore) / 10.0))
                            .stroke(recoveryColor(viewModel.snapshot.recoveryScore).gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 54, height: 54)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(viewModel.snapshot.recoveryScore)")
                            .font(.title3.weight(.bold))
                    }
                    Text("Восст.")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                
                // TSB Gauge
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(.tertiary.opacity(0.3), lineWidth: 5)
                            .frame(width: 54, height: 54)
                        
                        let normTsb = max(-30.0, min(30.0, viewModel.snapshot.tsb))
                        let trimVal = CGFloat((normTsb + 30.0) / 60.0)
                        
                        Circle()
                            .trim(from: 0, to: trimVal)
                            .stroke(tsbColor(viewModel.snapshot.tsb).gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 54, height: 54)
                            .rotationEffect(.degrees(-90))
                        
                        Text(String(format: "%+.0f", viewModel.snapshot.tsb))
                            .font(.title3.weight(.bold))
                    }
                    Text("Форма")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
            
            Text(tsbTaperMessage(viewModel.snapshot.tsb))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: 20)
        }
    }
    
    private func recoveryColor(_ score: Int) -> Color {
        if score >= 8 { return .green }
        if score >= 5 { return .yellow }
        return .red
    }
    
    private func tsbColor(_ tsb: Double) -> Color {
        if tsb > 10 { return .green }
        if tsb >= 0 { return .blue }
        if tsb >= -10 { return .orange }
        if tsb >= -30 { return .red }
        return .purple
    }
    
    private func tsbTaperMessage(_ tsb: Double) -> String {
        if tsb > 10 { return "Race Ready" }
        if tsb >= 0 { return "Optimal Form" }
        if tsb >= -10 { return "Development" }
        return "High Fatigue"
    }
}

// MARK: - Screen 2: Form Screen (PMC values)
struct WatchFormScreen: View {
    @EnvironmentObject var viewModel: WatchViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Баланс формы")
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Divider()
            
            VStack(spacing: 6) {
                HStack {
                    Text("CTL (Фитнес)").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f", viewModel.snapshot.ctl))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                }
                
                HStack {
                    Text("ATL (Усталость)").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f", viewModel.snapshot.atl))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red)
                }
                
                HStack {
                    Text("TSB (Форма)").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%+.1f", viewModel.snapshot.tsb))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.top, 4)
    }
}

// MARK: - Screen 3: Weekly Progress
struct WatchWeeklyProgressScreen: View {
    @EnvironmentObject var viewModel: WatchViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Объём за неделю")
                .font(.headline)
                .foregroundStyle(.yellow)
            
            Divider()
            
            let distKm = viewModel.snapshot.weeklyDistanceMeters / 1000.0
            let targetKm = viewModel.snapshot.weeklyGoalMeters / 1000.0
            let progress = targetKm > 0 ? (distKm / targetKm) : 0.0
            
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(.tertiary.opacity(0.3), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1.0, progress)))
                        .stroke(.yellow.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    
                    Text(String(format: "%.0f%%", progress * 100.0))
                        .font(.system(size: 10, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "Выполнено: %.1f км", distKm))
                        .font(.caption2.weight(.bold))
                    Text(String(format: "Цель: %.0f км", targetKm))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(.top, 4)
    }
}

// MARK: - Screen 4: Last Workout Summary
struct WatchLastWorkoutScreen: View {
    @EnvironmentObject var viewModel: WatchViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Крайняя тренировка")
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Divider()
            
            if let name = viewModel.snapshot.lastActivityName {
                Text(name)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let dist = viewModel.snapshot.lastActivityDistance {
                    Text(String(format: "Дистанция: %.2f км", dist / 1000.0))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                
                if let date = viewModel.snapshot.lastActivityDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("Нет тренировок")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)
            }
        }
        .padding(.top, 4)
    }
}
