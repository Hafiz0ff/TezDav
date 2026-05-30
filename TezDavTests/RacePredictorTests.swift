import XCTest
import CoreLocation
@testable import TezDav

final class RacePredictorTests: XCTestCase {
    
    func testExponentCalculationFromCTL() {
        // Test lower bounds clamping (CTL <= 10 results in 1.12)
        XCTAssertEqual(RacePredictorEngine.calculateExponent(ctl: 0), 1.12, accuracy: 0.001)
        XCTAssertEqual(RacePredictorEngine.calculateExponent(ctl: 10), 1.12, accuracy: 0.001)
        
        // Test upper bounds clamping (CTL >= 80 results in 1.04)
        XCTAssertEqual(RacePredictorEngine.calculateExponent(ctl: 80), 1.04, accuracy: 0.001)
        XCTAssertEqual(RacePredictorEngine.calculateExponent(ctl: 100), 1.04, accuracy: 0.001)
        
        // Test middle value (CTL = 45 results in 1.08)
        XCTAssertEqual(RacePredictorEngine.calculateExponent(ctl: 45), 1.08, accuracy: 0.001)
    }
    
    func testTemperatureFactors() {
        // Optimal temperature (10C) should have no penalty
        XCTAssertEqual(RacePredictorEngine.calculateTemperatureFactor(temperature: 10.0, distance: 10000.0), 1.0, accuracy: 0.001)
        
        // Heat penalty should be positive and stronger for longer distances
        let factor5kHeat = RacePredictorEngine.calculateTemperatureFactor(temperature: 30.0, distance: 5000.0)
        let factor42kHeat = RacePredictorEngine.calculateTemperatureFactor(temperature: 30.0, distance: 42195.0)
        
        XCTAssertGreaterThan(factor5kHeat, 1.0)
        XCTAssertGreaterThan(factor42kHeat, factor5kHeat)
        
        // Cold penalty should also add time
        let factorCold = RacePredictorEngine.calculateTemperatureFactor(temperature: -5.0, distance: 10000.0)
        XCTAssertGreaterThan(factorCold, 1.0)
    }
    
    func testEffectiveDistance() {
        let distance = 10000.0 // 10k
        
        // No elevation gain should keep distance unchanged
        XCTAssertEqual(RacePredictorEngine.calculateEffectiveDistance(distance: distance, elevationGain: 0), distance)
        
        // 100m elevation gain should add 600m to effective distance
        let effective = RacePredictorEngine.calculateEffectiveDistance(distance: distance, elevationGain: 100.0)
        XCTAssertEqual(effective, 10600.0)
    }
    
    func testPredictionCalculations() {
        // Base case: 10k in 50 mins (3000 sec). CTL = 45. Optimal conditions.
        // Predict 10k in optimal conditions -> should equal 3000 sec
        let sameDistPrediction = RacePredictorEngine.predictTime(
            baseDistance: 10000.0,
            baseTime: 3000.0,
            targetDistance: 10000.0,
            ctl: 45.0,
            elevationGain: 0.0,
            temperatureCelsius: 10.0
        )
        XCTAssertEqual(sameDistPrediction, 3000.0, accuracy: 0.1)
        
        // 5k prediction from 10k in 50 mins (ctl=45 -> d=1.08)
        // Expected: 3000 * (5000/10000)^1.08 = 3000 * 0.473 = 1419 sec (23:39)
        let prediction5k = RacePredictorEngine.predictTime(
            baseDistance: 10000.0,
            baseTime: 3000.0,
            targetDistance: 5000.0,
            ctl: 45.0,
            elevationGain: 0.0,
            temperatureCelsius: 10.0
        )
        XCTAssertEqual(prediction5k, 3000.0 * pow(0.5, 1.08), accuracy: 1.0)
    }
    
    func testSplitsGeneration() {
        let baseDistance = 10000.0
        let baseTime = 3000.0 // 50 mins
        let targetDistance = 42195.0 // Marathon
        let ctl = 45.0
        
        // Metric splits
        let splitsMetric = RacePredictorEngine.generateSplits(
            baseDistance: baseDistance,
            baseTime: baseTime,
            targetDistance: targetDistance,
            ctl: ctl,
            totalElevationGain: 100.0,
            temperatureCelsius: 15.0,
            isMetric: true
        )
        
        XCTAssertEqual(splitsMetric.count, 43) // 42 * 1km + 1 * 195m
        
        guard let lastSplit = splitsMetric.last else {
            XCTFail("Splits should not be empty")
            return
        }
        
        // Cumulative distance of final split should match target distance exactly
        XCTAssertEqual(lastSplit.cumulativeDistance, targetDistance, accuracy: 0.001)
        XCTAssertEqual(lastSplit.splitDistance, 195.0, accuracy: 0.1)
        
        // Sum of all splits duration should match the total predicted duration
        let predictedTotal = RacePredictorEngine.predictTime(
            baseDistance: baseDistance,
            baseTime: baseTime,
            targetDistance: targetDistance,
            ctl: ctl,
            elevationGain: 100.0,
            temperatureCelsius: 15.0
        )
        XCTAssertEqual(lastSplit.cumulativeDuration, predictedTotal, accuracy: 0.1)
    }
}
