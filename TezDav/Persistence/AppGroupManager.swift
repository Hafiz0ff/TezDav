import Foundation

struct DashboardSnapshot: Codable {
    let ctl: Double
    let atl: Double
    let tsb: Double
    let weeklyDistanceMeters: Double
    let weeklyDuration: TimeInterval
    let weeklyGoalMeters: Double
    let weeklyCyclingGoalHours: Double
    let recoveryScore: Int
    let lastActivityName: String?
    let lastActivityDate: Date?
    let lastActivityDistance: Double?
}

struct AppGroupManager {
    static let sharedSuite = "group.com.hafizov.tezdav"
    
    static func saveSnapshot(_ snapshot: DashboardSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            let defaults = UserDefaults(suiteName: sharedSuite)
            defaults?.set(data, forKey: "dashboard_snapshot")
            defaults?.synchronize()
        }
    }
    
    static func readSnapshot() -> DashboardSnapshot? {
        let defaults = UserDefaults(suiteName: sharedSuite)
        if let data = defaults?.data(forKey: "dashboard_snapshot") {
            return try? JSONDecoder().decode(DashboardSnapshot.self, from: data)
        }
        // Return dummy default snapshot to let widgets display nice mock data if no sync has run yet
        return DashboardSnapshot(
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
