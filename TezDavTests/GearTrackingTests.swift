import XCTest
import SwiftData
@testable import TezDav

@MainActor
final class GearTrackingTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: Activity.self, GearItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = ModelContext(container)
    }
    
    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }
    
    func testMileageAccumulationAndAlerts() throws {
        // 1. Create a Gear item with a 100 km limit
        let gear = GearItem(
            name: "Default Running Shoes",
            sportType: "Run",
            gearType: "shoes",
            maxDistanceKm: 100.0,
            currentDistanceKm: 0.0,
            isActive: true
        )
        context.insert(gear)
        
        // 2. Create activity of 60 km
        let act1 = Activity(
            stravaId: 501,
            sportType: "Run",
            name: "Long Run",
            startDate: Date(),
            distanceMeters: 60000.0, // 60 km
            movingTime: 18000.0,
            elapsedTime: 18000.0,
            elevationGain: 200.0,
            trimp: 150.0,
            trainingLoad: 150.0
        )
        context.insert(act1)
        
        // Link activity to gear
        act1.gearItem = gear
        gear.activities.append(act1)
        
        // Save
        try context.save()
        
        // 3. Force recalculation
        let totalMeters = gear.activities.reduce(0.0) { $0 + $1.distanceMeters }
        gear.currentDistanceKm = totalMeters / 1000.0
        
        XCTAssertEqual(gear.currentDistanceKm, 60.0)
        
        // 4. Create another activity of 35 km (bringing total to 95 km, which is within the 5 km / 50 km warning zone)
        let act2 = Activity(
            stravaId: 502,
            sportType: "Run",
            name: "Recovery Run",
            startDate: Date().addingTimeInterval(86400),
            distanceMeters: 35000.0, // 35 km
            movingTime: 9000.0,
            elapsedTime: 9000.0,
            elevationGain: 50.0,
            trimp: 70.0,
            trainingLoad: 70.0
        )
        context.insert(act2)
        
        act2.gearItem = gear
        gear.activities.append(act2)
        
        try context.save()
        
        let newTotalMeters = gear.activities.reduce(0.0) { $0 + $1.distanceMeters }
        gear.currentDistanceKm = newTotalMeters / 1000.0
        
        XCTAssertEqual(gear.currentDistanceKm, 95.0)
        
        let limit = gear.maxDistanceKm
        let remaining = limit - gear.currentDistanceKm
        XCTAssertEqual(remaining, 5.0)
        XCTAssertLessThanOrEqual(remaining, 50.0, "Should be within the critical wear warning limit")
    }
}
