import XCTest
import SwiftData
@testable import TezDav

final class FTPTestTests: XCTestCase {
    
    func testFTPSolverWithEmptySamples() {
        let samples: [ActivityStreamSample] = []
        let ftp = FTPTestSolver.solveFTP(samples: samples)
        XCTAssertNil(ftp)
    }
    
    func testFTPSolverWithTooShortDuration() {
        // Less than 20 minutes (1200 seconds)
        var samples: [ActivityStreamSample] = []
        for offset in 0..<600 {
            let sample = ActivityStreamSample(
                activityId: 101,
                offsetSeconds: offset,
                distanceMeters: Double(offset) * 5.0,
                latitude: 38.56,
                longitude: 68.82,
                heartRate: 150,
                cadence: 90,
                power: 300.0,
                speed: 5.0,
                altitude: 800.0
            )
            samples.append(sample)
        }
        let ftp = FTPTestSolver.solveFTP(samples: samples)
        XCTAssertNil(ftp)
    }
    
    func testFTPSolverWithValidSamples() {
        // Create 25 minutes of samples (1500 seconds)
        // From 0 to 200 seconds: 200W
        // From 200 to 1400 seconds (20 minutes / 1200 seconds): 300W (Peak)
        // From 1400 to 1500 seconds: 150W
        var samples: [ActivityStreamSample] = []
        for offset in 0...1500 {
            var powerVal = 200.0
            if offset >= 200 && offset < 1400 {
                powerVal = 300.0
            } else if offset >= 1400 {
                powerVal = 150.0
            }
            
            let sample = ActivityStreamSample(
                activityId: 102,
                offsetSeconds: offset,
                distanceMeters: Double(offset) * 5.0,
                latitude: 38.56,
                longitude: 68.82,
                heartRate: 160,
                cadence: 95,
                power: powerVal,
                speed: 5.0,
                altitude: 800.0
            )
            samples.append(sample)
        }
        
        let ftp = FTPTestSolver.solveFTP(samples: samples)
        XCTAssertNotNil(ftp)
        
        // Expected average power over the best 20-minute window (200..1400) is 300.0W.
        // FTP is 95% of that, so 300 * 0.95 = 285.0W.
        XCTAssertEqual(ftp!, 285.0, accuracy: 0.1)
    }
}
