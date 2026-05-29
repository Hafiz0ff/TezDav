import Foundation

struct DashboardSummary {
    let ctl: Double
    let atl: Double
    let tsb: Double
    let weeklyDistanceMeters: Double
    let weeklyDuration: TimeInterval
    let latestActivities: [Activity]

    static let empty = DashboardSummary(
        ctl: 0,
        atl: 0,
        tsb: 0,
        weeklyDistanceMeters: 0,
        weeklyDuration: 0,
        latestActivities: []
    )
}

enum DashboardViewModel {
    static func summary(from activities: [Activity], now: Date = .now, calendar: Calendar = .current) -> DashboardSummary {
        let sorted = activities.sorted { $0.startDate < $1.startDate }
        let points = TrainingLoadCalculator.performanceManagement(loads: sorted.map { ($0.startDate, $0.trainingLoad) })
        let current = points.last
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now.addingTimeInterval(-7 * 24 * 3600)
        let week = activities.filter { $0.startDate >= weekStart && $0.startDate <= now }
        let latest = activities.sorted { $0.startDate > $1.startDate }.prefix(5)

        return DashboardSummary(
            ctl: current?.ctl ?? 0,
            atl: current?.atl ?? 0,
            tsb: current?.tsb ?? 0,
            weeklyDistanceMeters: week.reduce(0) { $0 + $1.distanceMeters },
            weeklyDuration: week.reduce(0) { $0 + $1.movingTime },
            latestActivities: Array(latest)
        )
    }
}
