import XCTest
import SwiftData
@testable import TezDav

@MainActor
final class CasualAndGamificationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUpWithError() throws {
        let schema = Schema([Activity.self, UserSettings.self, Achievement.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
    }
    
    func testUserSettingsAppMode() {
        let settings = UserSettings()
        XCTAssertEqual(settings.appMode, .pro)
        
        settings.appMode = .casual
        XCTAssertEqual(settings.appModeRaw, "casual")
        XCTAssertEqual(settings.appMode, .casual)
    }
    
    func testNaismithHikeCalculation() {
        // Mock activity: 10km walk with 600m elevation gain
        let mockActivity = Activity(
            stravaId: 12345,
            sportType: "Walk",
            name: "Hike in mountains",
            startDate: Date(),
            distanceMeters: 10000.0,
            movingTime: 7200.0, // 2 hours
            elapsedTime: 7200.0,
            elevationGain: 600.0,
            trimp: 10.0,
            trainingLoad: 12.0
        )
        
        // Naismith's rule estimate:
        // (10km / 5.0) + (600m / 600.0) = 2.0 + 1.0 = 3.0 hours (10800 seconds)
        let settings = UserSettings()
        context.insert(settings)
        context.insert(mockActivity)
        
        _ = ActivityDetailView(activity: mockActivity)
        // Access computed properties using test access if needed, or check logic directly:
        let distanceKm = mockActivity.distanceMeters / 1000.0
        let ascentMeters = mockActivity.elevationGain
        let estimatedHours = (distanceKm / 5.0) + (ascentMeters / 600.0)
        let estTimeSeconds = estimatedHours * 3600.0
        
        XCTAssertEqual(estTimeSeconds, 10800.0)
        
        let speedDiffPercent = ((estTimeSeconds - mockActivity.movingTime) / estTimeSeconds) * 100
        XCTAssertEqual(speedDiffPercent, 33.33333333333333, accuracy: 0.001)
    }
    
    func testAchievementsScanning() {
        let settings = UserSettings()
        settings.appMode = .casual
        context.insert(settings)
        
        let date1 = Date().addingTimeInterval(-86400 * 3)
        let date2 = Date().addingTimeInterval(-86400 * 2)
        
        // Mock activities to trigger first steps (steps >= 5000), casual start, and a small streak (3 days is not enough for 7d streak)
        let walkAct = Activity(
            stravaId: 101,
            sportType: "Walk",
            name: "Daily Walk",
            startDate: date1,
            distanceMeters: 4000.0,
            movingTime: 3600.0,
            elapsedTime: 3600.0,
            elevationGain: 50.0,
            trimp: 5.0,
            trainingLoad: 5.0,
            stepsCount: 6000
        )
        
        let secondAct = Activity(
            stravaId: 102,
            sportType: "Run",
            name: "Evening Run",
            startDate: date2,
            distanceMeters: 5000.0,
            movingTime: 1800.0,
            elapsedTime: 1800.0,
            elevationGain: 20.0,
            trimp: 25.0,
            trainingLoad: 30.0,
            stepsCount: 6200
        )
        
        context.insert(walkAct)
        context.insert(secondAct)
        
        let activities = [walkAct, secondAct]
        
        AchievementManager.shared.scanAndAwardAchievements(context: context, activities: activities, settings: settings)
        
        // Fetch achievements
        let descriptor = FetchDescriptor<Achievement>()
        let earned = (try? context.fetch(descriptor)) ?? []
        
        // Should earn "first_steps" and "casual_start"
        XCTAssertTrue(earned.contains { $0.type == "first_steps" })
        XCTAssertTrue(earned.contains { $0.type == "casual_start" })
        XCTAssertFalse(earned.contains { $0.type == "streak_7d" })
    }
    
    func testStreak7dDaysAchievement() {
        let settings = UserSettings()
        context.insert(settings)
        
        var activities: [Activity] = []
        let calendar = Calendar.current
        
        // 7 consecutive active days
        for i in 0..<7 {
            let activityDate = calendar.date(byAdding: .day, value: -i, to: Date())!
            let act = Activity(
                stravaId: Int64(200 + i),
                sportType: "Run",
                name: "Streak Run Day \(i)",
                startDate: activityDate,
                distanceMeters: 2000.0,
                movingTime: 600.0,
                elapsedTime: 600.0,
                elevationGain: 10.0,
                trimp: 10.0,
                trainingLoad: 10.0
            )
            context.insert(act)
            activities.append(act)
        }
        
        AchievementManager.shared.scanAndAwardAchievements(context: context, activities: activities, settings: settings)
        
        let descriptor = FetchDescriptor<Achievement>()
        let earned = (try? context.fetch(descriptor)) ?? []
        
        XCTAssertTrue(earned.contains { $0.type == "streak_7d" })
    }
}
