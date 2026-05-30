import XCTest
import SwiftData
@testable import TezDav

final class AICoachTests: XCTestCase {
    
    private var modelContainer: ModelContainer!
    private var context: ModelContext!
    
    @MainActor
    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            modelContainer = try ModelContainer(
                for: Activity.self,
                ActivityStreamSample.self,
                SyncState.self,
                UserSettings.self,
                TrainingWeek.self,
                SavedRoute.self,
                Segment.self,
                SegmentEffort.self,
                configurations: config
            )
            context = modelContainer.mainContext
        } catch {
            XCTFail("Failed to initialize in-memory container: \(error)")
        }
    }
    
    override func tearDown() {
        context = nil
        modelContainer = nil
        super.tearDown()
    }
    
    @MainActor
    func testComplianceCalculation() {
        let now = Date()
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
        
        // 1. Create a planned week for the previous week
        let prevWeek = TrainingWeek(
            id: "week_prev",
            startDate: previousWeekStart,
            typeString: "Базовая",
            targetVolumeMeters: 40000.0, // 40km
            targetCyclingHours: 4.0      // 4 hours
        )
        context.insert(prevWeek)
        
        // 2. Create activities representing 50% running and 75% cycling compliance
        let actRun = Activity(
            stravaId: 101,
            sportType: "Run",
            name: "Interval Run",
            startDate: previousWeekStart.addingTimeInterval(86400 * 2),
            distanceMeters: 20000.0, // 20km (50% of 40km)
            movingTime: 7200,
            elapsedTime: 7200,
            elevationGain: 100,
            trimp: 120,
            trainingLoad: 120
        )
        let actBike = Activity(
            stravaId: 102,
            sportType: "Ride",
            name: "Morning Ride",
            startDate: previousWeekStart.addingTimeInterval(86400 * 4),
            distanceMeters: 90000.0,
            movingTime: 10800, // 3 hours (75% of 4 hours)
            elapsedTime: 10800,
            elevationGain: 500,
            trimp: 150,
            trainingLoad: 150
        )
        context.insert(actRun)
        context.insert(actBike)
        
        // Let's add a planned week for the next week
        let nextWeek = TrainingWeek(
            id: "week_next",
            startDate: currentWeekStart,
            typeString: "Развивающая",
            targetVolumeMeters: 45000.0,
            targetCyclingHours: 5.0
        )
        context.insert(nextWeek)
        
        let settings = UserSettings()
        
        let rec = AICoachEngine.analyze(
            activities: [actRun, actBike],
            plannedWeeks: [prevWeek, nextWeek],
            userSettings: settings,
            now: now
        )
        
        XCTAssertEqual(rec.targetRunMeters, 40000.0)
        XCTAssertEqual(rec.actualRunMeters, 20000.0)
        XCTAssertEqual(rec.runCompliance, 0.5)
        
        XCTAssertEqual(rec.targetBikeHours, 4.0)
        XCTAssertEqual(rec.actualBikeHours, 3.0)
        XCTAssertEqual(rec.bikeCompliance, 0.75)
    }
    
    @MainActor
    func testFatigueSpikeOverload() {
        let now = Date()
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
        
        // 1. Setup high volume last week
        let prevWeek = TrainingWeek(
            id: "week_prev",
            startDate: previousWeekStart,
            typeString: "Ударная",
            targetVolumeMeters: 50000.0,
            targetCyclingHours: 5.0
        )
        context.insert(prevWeek)
        
        // Next planned week
        let nextWeek = TrainingWeek(
            id: "week_next",
            startDate: currentWeekStart,
            typeString: "Ударная",
            targetVolumeMeters: 60000.0,
            targetCyclingHours: 6.0
        )
        context.insert(nextWeek)
        
        // Create an activity with huge load to drive TSB below -30
        let act1 = Activity(
            stravaId: 201,
            sportType: "Run",
            name: "Extreme Run",
            startDate: now.addingTimeInterval(-86400 * 3),
            distanceMeters: 30000.0,
            movingTime: 10000,
            elapsedTime: 10000,
            elevationGain: 100,
            trimp: 400,
            trainingLoad: 450 // Heavy load
        )
        context.insert(act1)
        
        let settings = UserSettings()
        let rec = AICoachEngine.analyze(
            activities: [act1],
            plannedWeeks: [prevWeek, nextWeek],
            userSettings: settings,
            now: now
        )
        
        XCTAssertEqual(rec.status, .overload)
        XCTAssertTrue(rec.isAdjustmentRecommended)
        // 25% reduction: 60000 * 0.75 = 45000, 6 * 0.75 = 4.5
        XCTAssertEqual(rec.recommendedRunMeters, 45000.0)
        XCTAssertEqual(rec.recommendedBikeHours, 4.5)
        XCTAssertTrue(rec.insightRU.contains("утомления"))
        XCTAssertTrue(rec.insightEN.contains("fatigue"))
    }
    
    @MainActor
    func testLowComplianceRecovery() {
        let now = Date()
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
        
        // Target is 40km, actual is 10km (25% compliance, which is < 60%)
        let prevWeek = TrainingWeek(
            id: "week_prev",
            startDate: previousWeekStart,
            typeString: "Базовая",
            targetVolumeMeters: 40000.0,
            targetCyclingHours: 0.0
        )
        context.insert(prevWeek)
        
        let nextWeek = TrainingWeek(
            id: "week_next",
            startDate: currentWeekStart,
            typeString: "Развивающая",
            targetVolumeMeters: 50000.0,
            targetCyclingHours: 0.0
        )
        context.insert(nextWeek)
        
        let act1 = Activity(
            stravaId: 301,
            sportType: "Run",
            name: "Short Run",
            startDate: previousWeekStart.addingTimeInterval(86400 * 2),
            distanceMeters: 10000.0, // 10km (25% compliance)
            movingTime: 3600,
            elapsedTime: 3600,
            elevationGain: 0,
            trimp: 50,
            trainingLoad: 50
        )
        context.insert(act1)
        
        let settings = UserSettings()
        let rec = AICoachEngine.analyze(
            activities: [act1],
            plannedWeeks: [prevWeek, nextWeek],
            userSettings: settings,
            now: now
        )
        
        XCTAssertEqual(rec.status, .recovery)
        XCTAssertTrue(rec.isAdjustmentRecommended)
        // 20% reduction: 50000 * 0.80 = 40000
        XCTAssertEqual(rec.recommendedRunMeters, 40000.0)
        XCTAssertTrue(rec.insightRU.contains("выполнили менее"))
        XCTAssertTrue(rec.insightEN.contains("completed less than"))
    }
    
    @MainActor
    func testFreshUnderload() {
        let now = Date()
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
        
        var mockActivities: [Activity] = []
        // 1. Build up fitness in the past: 30 days of daily load = 100
        for day in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -45 + day, to: now) else { continue }
            let act = Activity(
                stravaId: Int64(1000 + day),
                sportType: "Run",
                name: "Base Workout",
                startDate: date,
                distanceMeters: 10000.0,
                movingTime: 3600,
                elapsedTime: 3600,
                elevationGain: 0,
                trimp: 100,
                trainingLoad: 100
            )
            mockActivities.append(act)
        }
        
        // 2. Recovery steps to decay ATL (day -15 to -6)
        for day in 0..<10 {
            guard let date = calendar.date(byAdding: .day, value: -15 + day, to: now) else { continue }
            let act = Activity(
                stravaId: Int64(2000 + day),
                sportType: "Run",
                name: "Recovery Walk",
                startDate: date,
                distanceMeters: 1000.0,
                movingTime: 600,
                elapsedTime: 600,
                elevationGain: 0,
                trimp: 1,
                trainingLoad: 1
            )
            mockActivities.append(act)
        }
        
        // 3. Create planned week and high compliance workout in the previous week (day -5)
        let prevWeek = TrainingWeek(
            id: "week_prev",
            startDate: previousWeekStart,
            typeString: "Базовая",
            targetVolumeMeters: 10000.0, // 10km target
            targetCyclingHours: 0.0
        )
        context.insert(prevWeek)
        
        let prevWeekAct = Activity(
            stravaId: 3001,
            sportType: "Run",
            name: "Previous Week Run",
            startDate: previousWeekStart.addingTimeInterval(86400 * 2), // Day -5
            distanceMeters: 10000.0, // 10km (100% compliance)
            movingTime: 3600,
            elapsedTime: 3600,
            elevationGain: 0,
            trimp: 20, // light load
            trainingLoad: 20
        )
        mockActivities.append(prevWeekAct)
        
        // 4. More recovery steps from day -4 to -1
        for day in 0..<4 {
            guard let date = calendar.date(byAdding: .day, value: -4 + day, to: now) else { continue }
            let act = Activity(
                stravaId: Int64(4000 + day),
                sportType: "Run",
                name: "Recovery Walk",
                startDate: date,
                distanceMeters: 1000.0,
                movingTime: 600,
                elapsedTime: 600,
                elevationGain: 0,
                trimp: 1,
                trainingLoad: 1
            )
            mockActivities.append(act)
        }
        
        // Next planned week
        let nextWeek = TrainingWeek(
            id: "week_next",
            startDate: currentWeekStart,
            typeString: "Развивающая",
            targetVolumeMeters: 44000.0,
            targetCyclingHours: 2.5
        )
        context.insert(nextWeek)
        
        for act in mockActivities {
            context.insert(act)
        }
        
        let settings = UserSettings()
        let rec = AICoachEngine.analyze(
            activities: mockActivities,
            plannedWeeks: [prevWeek, nextWeek],
            userSettings: settings,
            now: now
        )
        
        XCTAssertEqual(rec.status, .underload)
        XCTAssertTrue(rec.isAdjustmentRecommended)
        // +5% load: 44000 * 1.05 = 46200, 2.5 * 1.05 = 2.625 -> round to 2.6
        XCTAssertEqual(rec.recommendedRunMeters, 46200.0)
        XCTAssertEqual(rec.recommendedBikeHours, 2.6)
    }
    
    @MainActor
    func testApplyAdaptation() {
        let now = Date()
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
        
        let prevWeek = TrainingWeek(
            id: "week_prev",
            startDate: previousWeekStart,
            typeString: "Базовая",
            targetVolumeMeters: 40000.0,
            targetCyclingHours: 4.0
        )
        context.insert(prevWeek)
        
        let nextWeek = TrainingWeek(
            id: "week_next",
            startDate: currentWeekStart,
            typeString: "Развивающая",
            targetVolumeMeters: 50000.0,
            targetCyclingHours: 5.0
        )
        context.insert(nextWeek)
        
        // Low compliance activity (only 10km run out of 40km)
        let act1 = Activity(
            stravaId: 501,
            sportType: "Run",
            name: "Lazy Run",
            startDate: previousWeekStart.addingTimeInterval(86400 * 2),
            distanceMeters: 10000.0,
            movingTime: 3600,
            elapsedTime: 3600,
            elevationGain: 0,
            trimp: 50,
            trainingLoad: 50
        )
        context.insert(act1)
        
        let settings = UserSettings()
        let rec = AICoachEngine.analyze(
            activities: [act1],
            plannedWeeks: [prevWeek, nextWeek],
            userSettings: settings,
            now: now
        )
        
        XCTAssertTrue(rec.isAdjustmentRecommended)
        
        // Apply adaptation
        AICoachEngine.applyAdaptation(
            recommendation: rec,
            in: context,
            plannedWeeks: [prevWeek, nextWeek],
            now: now
        )
        
        // Fetch nextWeek again and check targets
        XCTAssertEqual(nextWeek.targetVolumeMeters, 40000.0) // 50000 * 0.80 = 40000
        XCTAssertEqual(nextWeek.targetCyclingHours, 4.0)      // 5.0 * 0.80 = 4.0
        XCTAssertTrue(nextWeek.typeString.contains("Адапт") || nextWeek.typeString.contains("Adapted"))
    }
}
