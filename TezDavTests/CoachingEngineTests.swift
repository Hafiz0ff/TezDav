import XCTest
import SwiftData
@testable import TezDav

final class CoachingEngineTests: XCTestCase {
    
    func testSafetyInsightTriggered() {
        // Create an activity history that leads to extremely negative TSB
        // TSB is calculated as CTL - ATL.
        // Let's create an activity setup or use absolute summary calculations to test the rule directly.
        var activities: [Activity] = []
        for i in 0..<14 {
            let act = Activity(
                stravaId: Int64(i),
                sportType: "Run",
                name: "Intense Run",
                startDate: Date().addingTimeInterval(Double(-i) * 86400.0),
                distanceMeters: 15000.0,
                movingTime: 3600.0,
                elapsedTime: 3600.0,
                elevationGain: 100.0,
                trimp: 180.0,
                trainingLoad: 180.0
            )
            activities.append(act)
        }
        
        let settings = UserSettings()
        let insights = CoachingEngine.generateInsights(activities: activities, settings: settings, gears: [])
        
        // Find safety insight
        let safety = insights.first { $0.category == "safety" }
        XCTAssertNotNil(safety, "Safety insight should be triggered when fatigue is extremely high (low TSB)")
        XCTAssertTrue(safety?.titleEn.contains("High Overload") ?? false)
    }
    
    func testRunningCadenceInsight() {
        // Create run activities with very low cadence
        var activities: [Activity] = []
        for i in 0..<3 {
            let act = Activity(
                stravaId: Int64(i),
                sportType: "Run",
                name: "Slow Run",
                startDate: Date().addingTimeInterval(Double(-i) * 86400.0),
                distanceMeters: 5000.0,
                movingTime: 1800.0,
                elapsedTime: 1800.0,
                elevationGain: 10.0,
                averageHeartRate: 140.0,
                averageCadence: 158.0, // below 165
                trimp: 40.0,
                trainingLoad: 40.0
            )
            activities.append(act)
        }
        
        let settings = UserSettings()
        let insights = CoachingEngine.generateInsights(activities: activities, settings: settings, gears: [])
        
        let technique = insights.first { $0.category == "technique" }
        XCTAssertNotNil(technique, "Technique advice should be triggered when average cadence is low")
        XCTAssertTrue(technique?.titleEn.contains("Cadence") ?? false)
    }
    
    func testGearWearInsight() {
        let badGear = GearItem(
            name: "Vaporfly",
            sportType: "Run",
            gearType: "shoes",
            brand: "Nike",
            maxDistanceKm: 500.0,
            currentDistanceKm: 460.0, // 92% wear (exceeds 85%)
            isActive: true
        )
        
        let insights = CoachingEngine.generateInsights(activities: [], settings: UserSettings(), gears: [badGear])
        
        let gearInsight = insights.first { $0.category == "gear" }
        XCTAssertNotNil(gearInsight, "Gear replacement alert should trigger when wear exceeds 85%")
        XCTAssertTrue(gearInsight?.messageEn.contains("Vaporfly") ?? false)
    }
}
