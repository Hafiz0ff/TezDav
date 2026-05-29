import SwiftUI
import WidgetKit

// Timeline Provider loading data from shared App Group suite
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), snapshot: defaultSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let snapshot = AppGroupManager.readSnapshot() ?? defaultSnapshot()
        let entry = SimpleEntry(date: Date(), snapshot: snapshot)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let snapshot = AppGroupManager.readSnapshot() ?? defaultSnapshot()
        let entry = SimpleEntry(date: Date(), snapshot: snapshot)
        
        // Updates once every hour or on reload request from main app
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func defaultSnapshot() -> DashboardSnapshot {
        DashboardSnapshot(
            ctl: 45.2,
            atl: 58.4,
            tsb: -13.2,
            weeklyDistanceMeters: 32400.0,
            weeklyDuration: 9400.0,
            weeklyGoalMeters: 50000.0,
            weeklyCyclingGoalHours: 5.0,
            recoveryScore: 7,
            lastActivityName: "Вечерний бег",
            lastActivityDate: Date().addingTimeInterval(-86400),
            lastActivityDistance: 10200.0
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let snapshot: DashboardSnapshot
}

// MARK: - Widget 1: TSB Widget (2x2 Circular Gauge)
struct TsbWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Форма (TSB)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            
            ZStack {
                Circle()
                    .stroke(.tertiary.opacity(0.3), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                let clampedTsb = max(-30.0, min(30.0, entry.snapshot.tsb))
                let progressVal = CGFloat((clampedTsb + 30.0) / 60.0)
                
                Circle()
                    .trim(from: 0, to: progressVal)
                    .stroke(tsbColor(entry.snapshot.tsb).gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Text(String(format: "%+.0f", entry.snapshot.tsb))
                    .font(.title3.weight(.bold))
            }
            
            Text(tsbLabel(entry.snapshot.tsb))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tsbColor(entry.snapshot.tsb))
        }
        .containerBackground(.background, for: .widget)
    }
    
    private func tsbColor(_ tsb: Double) -> Color {
        if tsb > 10 { return .green }
        if tsb >= 0 { return .blue }
        if tsb >= -10 { return .orange }
        if tsb >= -30 { return .red }
        return .purple
    }
    
    private func tsbLabel(_ tsb: Double) -> String {
        if tsb > 10 { return "Свежесть" }
        if tsb >= 0 { return "База" }
        if tsb >= -10 { return "Усталость" }
        return "Перегруз"
    }
}

// MARK: - Widget 2: Weekly Progress Widget (2x2 Progress Ring)
struct WeeklyProgressWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Неделя (км)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            
            let distKm = entry.snapshot.weeklyDistanceMeters / 1000.0
            let targetKm = entry.snapshot.weeklyGoalMeters / 1000.0
            let progress = targetKm > 0 ? (distKm / targetKm) : 0.0
            
            ZStack {
                Circle()
                    .stroke(.tertiary.opacity(0.3), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, progress)))
                    .stroke(Color.yellow.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 1) {
                    Text(String(format: "%.0f", distKm))
                        .font(.headline.weight(.bold))
                    Text(String(format: "/%.0f", targetKm))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(String(format: "Выполнено %.0f%%", progress * 100))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.yellow)
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Widget 3: Recovery Score Widget (2x2 score scale)
struct RecoveryWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 6) {
            Text("Восстановление")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            
            Text("\(entry.snapshot.recoveryScore)")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(recoveryColor(entry.snapshot.recoveryScore).gradient)
            
            Text(recoveryText(entry.snapshot.recoveryScore))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .containerBackground(.background, for: .widget)
    }
    
    private func recoveryColor(_ score: Int) -> Color {
        if score >= 8 { return .green }
        if score >= 5 { return .yellow }
        return .red
    }
    
    private func recoveryText(_ score: Int) -> String {
        if score >= 8 { return "Готов к нагрузке" }
        if score >= 5 { return "Умеренная форма" }
        return "Необходим отдых"
    }
}

// MARK: - Widget 4: Mini-Dashboard (2x4 Widget)
struct DashboardWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Панель TezDav")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Spacer()
                Text("Восст.: \(entry.snapshot.recoveryScore)/10")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                // CTL / ATL / TSB column
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CTL (Фитнес):").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f", entry.snapshot.ctl)).font(.caption2.weight(.bold))
                    }
                    HStack {
                        Text("ATL (Усталость):").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f", entry.snapshot.atl)).font(.caption2.weight(.bold)).foregroundStyle(.red)
                    }
                    HStack {
                        Text("TSB (Форма):").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%+.1f", entry.snapshot.tsb)).font(.caption2.weight(.bold)).foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                
                // Weekly / Last act column
                VStack(alignment: .leading, spacing: 4) {
                    let km = entry.snapshot.weeklyDistanceMeters / 1000.0
                    Text(String(format: "Неделя: %.1f км", km))
                        .font(.caption2.weight(.semibold))
                    
                    if let actName = entry.snapshot.lastActivityName {
                        Text("Последняя:")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(actName)
                            .font(.system(size: 9, weight: .bold))
                            .lineLimit(1)
                    } else {
                        Text("Нет занятий")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Widget 5: Lock Screen Widget (accessoryRectangular)
struct LockScreenWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("⚡️ TezDav Восстановление: \(entry.snapshot.recoveryScore)/10")
                .font(.caption2.weight(.semibold))
            Text(String(format: "Форма (TSB): %+.0f", entry.snapshot.tsb))
                .font(.caption)
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Widget Configurations

struct TsbWidget: Widget {
    let kind: String = "TsbWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TsbWidgetView(entry: entry)
        }
        .configurationDisplayName("Форма (TSB)")
        .description("Текущий баланс формы с цветовой индикацией усталости.")
        .supportedFamilies([.systemSmall])
    }
}

struct WeeklyProgressWidget: Widget {
    let kind: String = "WeeklyProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WeeklyProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("Недельный прогресс")
        .description("Прогресс недельного километража относительно вашей цели.")
        .supportedFamilies([.systemSmall])
    }
}

struct RecoveryWidget: Widget {
    let kind: String = "RecoveryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RecoveryWidgetView(entry: entry)
        }
        .configurationDisplayName("Восстановление")
        .description("Индикатор готовности вашего организма к тренировкам.")
        .supportedFamilies([.systemSmall])
    }
}

struct DashboardWidget: Widget {
    let kind: String = "DashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DashboardWidgetView(entry: entry)
        }
        .configurationDisplayName("Панель управления")
        .description("Краткая сводка тренировочной нагрузки и последней активности.")
        .supportedFamilies([.systemMedium])
    }
}

struct LockScreenWidget: Widget {
    let kind: String = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Текущий статус")
        .description("Ваши TSB и готовность организма на экране блокировки.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Bundle Entrypoint

@main
struct TezDavWidgetBundle: WidgetBundle {
    var body: some Widget {
        TsbWidget()
        WeeklyProgressWidget()
        RecoveryWidget()
        DashboardWidget()
        LockScreenWidget()
    }
}
