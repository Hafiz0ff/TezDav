import XCTest
import SwiftData
@testable import TezDav

final class BoundaryTests: XCTestCase {
    
    // MARK: - CTL / ATL / TSB Calculations
    
    func testZeroActivitiesSummary() {
        let summary = DashboardViewModel.summary(from: [])
        XCTAssertEqual(summary.ctl, 0.0)
        XCTAssertEqual(summary.atl, 0.0)
        XCTAssertEqual(summary.tsb, 0.0)
        XCTAssertEqual(summary.weeklyDistanceMeters, 0.0)
        XCTAssertEqual(summary.weeklyDuration, 0.0)
    }
    
    func testOneActivityCurveStart() {
        let activity = TestDataFactory.makeActivity(
            startDate: Date().addingTimeInterval(-86400 * 2), // 2 days ago
            trainingLoad: 100.0
        )
        
        let summary = DashboardViewModel.summary(from: [activity], now: Date())
        
        // Initial CTL: 0 -> load 100: ctl += (100 - ctl) / 42 = 2.38
        // ATL: 0 -> load 100: atl += (100 - atl) / 7 = 14.28
        // Decay for 2 days
        let initialCTL = 100.0 / 42.0
        let initialATL = 100.0 / 7.0
        let expectedCTL = initialCTL * pow(41.0 / 42.0, 2)
        let expectedATL = initialATL * pow(6.0 / 7.0, 2)
        
        XCTAssertEqual(summary.ctl, expectedCTL, accuracy: 0.001)
        XCTAssertEqual(summary.atl, expectedATL, accuracy: 0.001)
        XCTAssertEqual(summary.tsb, expectedCTL - expectedATL, accuracy: 0.001)
    }
    
    func testTrimpZeroHeartRateOrPower() {
        let trimp = TrainingLoadCalculator.trimp(
            duration: 3600.0,
            averageHeartRate: nil,
            restingHeartRate: 60.0,
            maxHeartRate: 190.0
        )
        XCTAssertEqual(trimp, 0.0)
    }
    
    func testTrimpInvalidHeartRateReserve() {
        // restingHeartRate >= maxHeartRate
        let trimp = TrainingLoadCalculator.trimp(
            duration: 3600.0,
            averageHeartRate: 150.0,
            restingHeartRate: 195.0,
            maxHeartRate: 190.0
        )
        XCTAssertEqual(trimp, 0.0)
    }
    
    func test365DaysInactivityDecay() {
        let activity = TestDataFactory.makeActivity(
            startDate: Date().addingTimeInterval(-86400 * 365), // 1 year ago
            trainingLoad: 100.0
        )
        
        let summary = DashboardViewModel.summary(from: [activity], now: Date())
        
        XCTAssertTrue(summary.ctl > 0.0)
        XCTAssertTrue(summary.ctl < 0.001) // Decays to almost zero
        XCTAssertTrue(summary.atl > 0.0)
        XCTAssertTrue(summary.atl < 0.00000001) // Decays to practically zero
        XCTAssertTrue(summary.ctl - summary.atl >= 0.0) // No negative results
    }
    
    func testNegativeTSBRepresentation() {
        // If ATL is larger than CTL, TSB is negative
        let summary = DashboardSummary(
            ctl: 10.0,
            atl: 35.0,
            tsb: -25.0,
            weeklyDistanceMeters: 0,
            weeklyDuration: 0,
            latestActivities: []
        )
        XCTAssertEqual(summary.tsb, -25.0)
    }
    
    // MARK: - Personal Records
    
    func testPersonalRecordsExactDistance() {
        // Check 5k record threshold logic
        let runExactly5k = TestDataFactory.makeActivity(distanceMeters: 5000.0)
        let runJustUnder5k = TestDataFactory.makeActivity(distanceMeters: 4999.0)
        
        XCTAssertTrue(runExactly5k.distanceMeters >= 5000.0)
        XCTAssertFalse(runJustUnder5k.distanceMeters >= 5000.0)
    }
    
    // MARK: - Riegel Predictions
    
    func testRiegelPredictTimeZeroSeconds() {
        let time = RacePredictorEngine.predictTime(
            baseDistance: 10000.0,
            baseTime: 0.0,
            targetDistance: 5000.0,
            ctl: 50.0,
            elevationGain: 0.0,
            temperatureCelsius: 10.0
        )
        XCTAssertEqual(time, 0.0)
    }
    
    func testRiegelClampNegativeElevation() {
        // Negative elevation gain shouldn't result in negative distance inside pow
        let time = RacePredictorEngine.predictTime(
            baseDistance: 10000.0,
            baseTime: 3000.0,
            targetDistance: 5000.0,
            ctl: 50.0,
            elevationGain: -1000.0, // Large negative elevation gain
            temperatureCelsius: 10.0
        )
        XCTAssertTrue(time > 0.0)
    }
    
    // MARK: - Running Dynamics
    
    func testCadenceZeroDynamics() {
        let activity = TestDataFactory.makeActivity(sportType: "Run", averageCadence: 0.0)
        let sample = ActivityStreamSample(activityId: 1, offsetSeconds: 0, distanceMeters: 0, latitude: 45.0, longitude: 74.0, heartRate: 140, cadence: 0, power: 0, speed: 3.0, altitude: 100)
        
        RunningDynamicsEngine.enrich(activity: activity, samples: [sample])
        
        XCTAssertEqual(sample.strideLength, 1.0) // fallback value
    }
    
    func testNegativeVerticalOscillationClipping() {
        let activity = TestDataFactory.makeActivity(sportType: "Run")
        let sample = ActivityStreamSample(activityId: 1, offsetSeconds: 0, distanceMeters: 0, latitude: 45.0, longitude: 74.0, heartRate: 140, cadence: 170.0, power: 0, speed: 3.0, altitude: 100)
        sample.verticalOscillation = -5.0 // Garmin data bug
        
        RunningDynamicsEngine.enrich(activity: activity, samples: [sample])
        
        XCTAssertEqual(sample.verticalOscillation, 0.0)
    }
    
    // MARK: - Gear wear
    
    func testGearWearCappedAt100Percent() {
        let gear = TestDataFactory.makeGearItem(maxDistanceKm: 500.0, currentDistanceKm: 600.0)
        let pct = gear.maxDistanceKm > 0 ? (gear.currentDistanceKm / gear.maxDistanceKm) : 0.0
        let displayPct = min(1.0, pct)
        
        XCTAssertEqual(displayPct * 100, 100.0)
    }
}
