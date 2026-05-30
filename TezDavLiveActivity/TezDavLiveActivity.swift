import ActivityKit
import SwiftUI
import WidgetKit

struct TezSyncLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TezDavAttributes.self) { context in
            // Lock Screen Banner UI
            TezDavLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: context.state.isSyncing ? "arrow.triangle.2.circlepath" : workoutIcon(for: context.state.sportType))
                            .font(.title2)
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading) {
                            Text(context.state.isSyncing ? (Locale.current.identifier.hasPrefix("ru") ? "Синхронизация" : "Syncing") : (context.state.workoutName ?? ""))
                                .font(.headline)
                                .fontWeight(.bold)
                            if context.state.isSyncing {
                                Text(String(format: Locale.current.identifier.hasPrefix("ru") ? "Загружено %d из %d" : "Loaded %d of %d", context.state.loadedCount, context.state.totalCount))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.leading, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.state.isSyncing, let load = context.state.trainingLoad {
                        VStack(alignment: .trailing) {
                            Text("TL")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f", load))
                                .font(.title3.bold())
                                .foregroundStyle(.orange)
                        }
                        .padding(.trailing, 8)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isSyncing {
                        ProgressView(value: Double(context.state.loadedCount), total: Double(max(1, context.state.totalCount)))
                            .tint(.purple)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    } else {
                        HStack(spacing: 16) {
                            if let dist = context.state.distanceMeters {
                                VStack(alignment: .leading) {
                                    Text(Locale.current.identifier.hasPrefix("ru") ? "Дистанция" : "Distance")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(formatDistance(dist))
                                        .font(.subheadline.bold())
                                }
                            }
                            if let dur = context.state.durationSeconds {
                                VStack(alignment: .leading) {
                                    Text(Locale.current.identifier.hasPrefix("ru") ? "Время" : "Time")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(formatDuration(dur))
                                        .font(.subheadline.bold())
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isSyncing ? "arrow.triangle.2.circlepath" : workoutIcon(for: context.state.sportType))
                    .foregroundStyle(.purple)
            } compactTrailing: {
                if context.state.isSyncing {
                    Text("\(context.state.loadedCount)/\(context.state.totalCount)")
                        .font(.caption2.bold())
                } else if let load = context.state.trainingLoad {
                    Text("TL \(Int(load))")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }
            } minimal: {
                Image(systemName: context.state.isSyncing ? "arrow.triangle.2.circlepath" : "figure.run")
                    .foregroundStyle(.purple)
            }
        }
    }
}

// Lock Screen UI
struct TezDavLiveActivityLockScreenView: View {
    let context: ActivityViewContext<TezDavAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: context.state.isSyncing ? "arrow.triangle.2.circlepath" : workoutIcon(for: context.state.sportType))
                    .font(.title2)
                    .foregroundStyle(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.isSyncing ? (Locale.current.identifier.hasPrefix("ru") ? "Синхронизация с Strava" : "Strava Synchronization") : (context.state.workoutName ?? (Locale.current.identifier.hasPrefix("ru") ? "Тренировка загружена" : "Workout Loaded")))
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    if context.state.isSyncing {
                        Text(String(format: Locale.current.identifier.hasPrefix("ru") ? "Загружено %d из %d" : "Loaded %d of %d", context.state.loadedCount, context.state.totalCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(Locale.current.identifier.hasPrefix("ru") ? "Импортирована новая тренировка" : "A new workout has been imported")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if !context.state.isSyncing, let load = context.state.trainingLoad {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Locale.current.identifier.hasPrefix("ru") ? "Нагрузка" : "Load")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f", load))
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            if context.state.isSyncing {
                ProgressView(value: Double(context.state.loadedCount), total: Double(max(1, context.state.totalCount)))
                    .tint(.purple)
            } else {
                HStack(spacing: 24) {
                    if let dist = context.state.distanceMeters {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Locale.current.identifier.hasPrefix("ru") ? "Дистанция" : "Distance")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(formatDistance(dist))
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    
                    if let dur = context.state.durationSeconds {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Locale.current.identifier.hasPrefix("ru") ? "Время" : "Time")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(formatDuration(dur))
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// Helpers
private func workoutIcon(for sport: String?) -> String {
    guard let sport = sport?.lowercased() else { return "figure.mixed.cardio" }
    if sport.contains("run") { return "figure.run" }
    if sport.contains("ride") || sport.contains("cycl") { return "bicycle" }
    if sport.contains("swim") { return "figure.pool.swim" }
    if sport.contains("walk") { return "figure.walk" }
    return "figure.mixed.cardio"
}

private func formatDistance(_ meters: Double) -> String {
    let isRussian = Locale.current.identifier.hasPrefix("ru")
    let km = meters / 1000.0
    return String(format: isRussian ? "%.2f км" : "%.2f km", km)
}

private func formatDuration(_ seconds: Double) -> String {
    let mins = Int(seconds) / 60
    let hours = mins / 60
    let remainingMins = mins % 60
    if hours > 0 {
        return String(format: "%d ч %02d м", hours, remainingMins)
    } else {
        return String(format: "%d м", remainingMins)
    }
}
