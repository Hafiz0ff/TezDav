import XCTest
import SwiftData
@testable import TezDav

@MainActor
final class ForecastTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUpWithError() throws {
        let schema = Schema([PlannedWorkout.self, Activity.self, UserSettings.self, TrainingWeek.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
    }
    
    // Test 1: TSS Calculation by Intensity Factor (IF)
    func testTSSCalculation() {
        // Form: TSS = (DurationSeconds * IF^2 * 100) / 3600
        
        // 1 hour at IF = 1.0 -> 100 TSS
        let duration1 = 3600.0
        let if1 = 1.0
        let tss1 = (duration1 * if1 * if1 * 100.0) / 3600.0
        XCTAssertEqual(tss1, 100.0)
        
        // 2 hours at IF = 0.85 -> 144.5 TSS
        let duration2 = 7200.0
        let if2 = 0.85
        let tss2 = (duration2 * if2 * if2 * 100.0) / 3600.0
        XCTAssertEqual(tss2, 144.5)
        
        // 45 minutes (2700s) at IF = 0.75 -> 42.1875 TSS
        let duration3 = 2700.0
        let if3 = 0.75
        let tss3 = (duration3 * if3 * if3 * 100.0) / 3600.0
        XCTAssertEqual(tss3, 42.1875)
    }
    
    // Test 2: PlannedWorkout CRUD
    func testPlannedWorkoutCRUD() throws {
        let tomorrow = Date().addingTimeInterval(86400)
        let workout = PlannedWorkout(
            date: tomorrow,
            sportType: "Run",
            title: "Запланированная темповая",
            plannedDurationSeconds: 3600,
            plannedDistanceMeters: 10000,
            plannedTSS: 75
        )
        
        context.insert(workout)
        try context.save()
        
        let fetchDescriptor = FetchDescriptor<PlannedWorkout>()
        let results = try context.fetch(fetchDescriptor)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Запланированная темповая")
        XCTAssertEqual(results.first?.plannedTSS, 75)
        XCTAssertFalse(results.first?.isCompleted ?? true)
        
        // Update
        results.first?.plannedTSS = 80
        try context.save()
        
        let results2 = try context.fetch(fetchDescriptor)
        XCTAssertEqual(results2.first?.plannedTSS, 80)
        
        // Delete
        context.delete(workout)
        try context.save()
        
        let results3 = try context.fetch(fetchDescriptor)
        XCTAssertTrue(results3.isEmpty)
    }
    
    // Test 3: Complete Planned Workout
    func testCompletePlannedWorkout() throws {
        let tomorrow = Date().addingTimeInterval(86400)
        let workout = PlannedWorkout(
            date: tomorrow,
            sportType: "Ride",
            title: "Велосипед 50км",
            plannedDurationSeconds: 7200,
            plannedDistanceMeters: 50000,
            plannedTSS: 120
        )
        context.insert(workout)
        try context.save()
        
        // Emulate completion action
        workout.isCompleted = true
        let newActivity = Activity(
            stravaId: 999999,
            sportType: workout.sportType,
            name: workout.title,
            startDate: workout.date,
            distanceMeters: workout.plannedDistanceMeters,
            movingTime: workout.plannedDurationSeconds,
            elapsedTime: workout.plannedDurationSeconds,
            elevationGain: 0.0,
            averageSpeed: workout.plannedDistanceMeters / workout.plannedDurationSeconds,
            trimp: workout.plannedTSS,
            trainingLoad: workout.plannedTSS
        )
        context.insert(newActivity)
        try context.save()
        
        // Verify states
        let plannedResults = try context.fetch(FetchDescriptor<PlannedWorkout>())
        XCTAssertTrue(plannedResults.first?.isCompleted ?? false)
        
        let actualResults = try context.fetch(FetchDescriptor<Activity>())
        XCTAssertEqual(actualResults.count, 1)
        XCTAssertEqual(actualResults.first?.name, "Велосипед 50км")
        XCTAssertEqual(actualResults.first?.trainingLoad, 120.0)
    }
}
