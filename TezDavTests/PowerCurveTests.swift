import XCTest
@testable import TezDav

final class PowerCurveTests: XCTestCase {
    
    func testPowerCurveCalculatorSteadyState() {
        // Arrange
        var samples: [ActivityStreamSample] = []
        for i in 0..<100 {
            samples.append(ActivityStreamSample(
                activityId: 123,
                offsetSeconds: i,
                distanceMeters: Double(i) * 5.0,
                latitude: 40.0,
                longitude: 69.0,
                heartRate: 150,
                cadence: 90,
                power: 300.0, // Steady 300W
                speed: 5.0,
                altitude: 100.0
            ))
        }
        
        // Act
        let peaks = PowerCurveCalculator.calculatePeaks(from: samples)
        
        // Assert
        XCTAssertEqual(peaks[1], 300.0)
        XCTAssertEqual(peaks[5], 300.0)
        XCTAssertEqual(peaks[30], 300.0)
        XCTAssertEqual(peaks[60], 300.0)
    }
    
    func testPowerCurveCalculatorPeakEffort() {
        // Arrange
        var samples: [ActivityStreamSample] = []
        for i in 0..<100 {
            // Steady 200W, but seconds 20 to 24 are 400W (5-second effort)
            let powerVal = (i >= 20 && i <= 24) ? 400.0 : 200.0
            samples.append(ActivityStreamSample(
                activityId: 123,
                offsetSeconds: i,
                distanceMeters: Double(i) * 5.0,
                latitude: 40.0,
                longitude: 69.0,
                heartRate: 150,
                cadence: 90,
                power: powerVal,
                speed: 5.0,
                altitude: 100.0
            ))
        }
        
        // Act
        let peaks = PowerCurveCalculator.calculatePeaks(from: samples)
        
        // Assert
        XCTAssertEqual(peaks[1], 400.0)
        XCTAssertEqual(peaks[5], 400.0)
        // 15-second peak should be: (5 * 400 + 10 * 200) / 15 = 4000 / 15 = 266.67
        XCTAssertEqual(peaks[15]!, 266.67, accuracy: 0.1)
    }
    
    func testCriticalPowerSolverValid() {
        // Arrange
        // For t1 = 300s, P1 = 350W => E1 = 105,000 J
        // For t2 = 1200s, P2 = 285W => E2 = 342,000 J
        // CP = (342000 - 105000) / 900 = 237000 / 900 = 263.33 W
        // W' = 105000 - 263.33 * 300 = 105000 - 79000 = 26,000 J
        var mmp: [Int: Double] = [:]
        mmp[300] = 350.0
        mmp[1200] = 285.0
        
        // Act
        let result = CriticalPowerSolver.solve(mmp: mmp, defaultFTP: 250.0)
        
        // Assert
        XCTAssertFalse(result.isEstimated)
        XCTAssertEqual(result.criticalPower, 263.33, accuracy: 0.1)
        XCTAssertEqual(result.wPrime, 26000.0, accuracy: 1.0)
    }
    
    func testCriticalPowerSolverFallback() {
        // Arrange: Unrealistic/noisy inputs (CP would be negative or W' out of range)
        var mmp: [Int: Double] = [:]
        mmp[300] = 200.0
        mmp[1200] = 250.0 // 20m power greater than 5m power is physiologically impossible
        
        // Act
        let result = CriticalPowerSolver.solve(mmp: mmp, defaultFTP: 220.0)
        
        // Assert
        XCTAssertTrue(result.isEstimated)
        XCTAssertEqual(result.criticalPower, 220.0)
        XCTAssertEqual(result.wPrime, 18000.0)
    }
}
