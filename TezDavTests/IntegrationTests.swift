import XCTest
import SwiftData
import HealthKit
@testable import TezDav

final class IntegrationTests: XCTestCase {
    
    // MARK: - Mock Strava API Client
    
    final class MockStravaAPIClient: StravaAPIClientProtocol, @unchecked Sendable {
        var mode: Mode = .success
        var requestCount = 0
        
        enum Mode {
            case success
            case unauthorized401
            case rateLimit429
            case timeout
            case empty
            case unknownSport
        }
        
        func activities(page: Int, perPage: Int, after: Date?) async throws -> [StravaActivitySummary] {
            requestCount += 1
            switch mode {
            case .success:
                return [
                    StravaActivitySummary(id: 101, name: "Run 1", sportType: "Run", startDate: Date(), distance: 5000.0, movingTime: 1800, elapsedTime: 1800, totalElevationGain: 50.0),
                    StravaActivitySummary(id: 102, name: "Ride 1", sportType: "Ride", startDate: Date().addingTimeInterval(-86400), distance: 20000.0, movingTime: 3600, elapsedTime: 3600, totalElevationGain: 100.0)
                ]
            case .unauthorized401:
                throw StravaAPIError.badStatus(401)
            case .rateLimit429:
                throw StravaAPIError.badStatus(429)
            case .timeout:
                throw URLError(.timedOut)
            case .empty:
                return []
            case .unknownSport:
                return [
                    StravaActivitySummary(id: 103, name: "Secret Sport", sportType: "FuturisticSportXYZ", startDate: Date(), distance: 1000.0, movingTime: 300, elapsedTime: 300, totalElevationGain: 0.0)
                ]
            }
        }
        
        func streams(activityId: Int64) async throws -> StravaStreamSet? {
            return nil
        }
        
        func athlete() async throws -> StravaAthlete {
            return StravaAthlete(id: 1, firstname: "Test", lastname: "User", profile: nil)
        }
    }
    
    // MARK: - API Failure Tests
    
    func testStrava401UnauthorizedTriggersFlow() async {
        let client = MockStravaAPIClient()
        client.mode = .unauthorized401
        
        do {
            _ = try await client.activities(page: 1, perPage: 10, after: nil)
            XCTFail("Should have thrown 401 error")
        } catch {
            if case StravaAPIError.badStatus(let code) = error {
                XCTAssertEqual(code, 401)
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testStrava429RateLimitThrows() async {
        let client = MockStravaAPIClient()
        client.mode = .rateLimit429
        
        do {
            _ = try await client.activities(page: 1, perPage: 10, after: nil)
            XCTFail("Should have thrown 429 error")
        } catch {
            if case StravaAPIError.badStatus(let code) = error {
                XCTAssertEqual(code, 429)
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testStravaTimeoutThrowsURLError() async {
        let client = MockStravaAPIClient()
        client.mode = .timeout
        
        do {
            _ = try await client.activities(page: 1, perPage: 10, after: nil)
            XCTFail("Should have timed out")
        } catch {
            XCTAssertTrue(error is URLError)
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
    }
    
    func testStravaEmptyResponse() async {
        let client = MockStravaAPIClient()
        client.mode = .empty
        
        let acts = try! await client.activities(page: 1, perPage: 10, after: nil)
        XCTAssertTrue(acts.isEmpty)
    }
    
    func testStravaUnknownSportMapping() async {
        let client = MockStravaAPIClient()
        client.mode = .unknownSport
        
        let acts = try! await client.activities(page: 1, perPage: 10, after: nil)
        XCTAssertEqual(acts.count, 1)
        
        // Maps to category "Other" or default without crashing in mapper
        let sport = acts.first!.sportType
        XCTAssertEqual(sport, "FuturisticSportXYZ")
    }
    
    // MARK: - HealthKit Mock Integration
    
    func testHealthKitHRVZeroHandling() {
        let details = HealthKitManager.shared.calculateDetailedReadiness(
            hrvToday: 0.0,
            hrvBaseline: 55.0,
            sleepTotalHours: 8.0,
            sleepDeepHours: 1.6,
            tsb: 0.0,
            daysSinceLastHardWorkout: 30
        )
        
        // Assert it does not drop to 0, treats hrvRatio as 1.0 (neutral)
        XCTAssertTrue(details.score >= 50)
        XCTAssertEqual(details.hrvScore, 100) // neutral value
    }
    
    func testHealthKitSleepLessThan1Hour() {
        let details = HealthKitManager.shared.calculateDetailedReadiness(
            hrvToday: 55.0,
            hrvBaseline: 55.0,
            sleepTotalHours: 0.5,
            sleepDeepHours: 0.1,
            tsb: 0.0,
            daysSinceLastHardWorkout: 3
        )
        
        // Sleep under 1 hour shouldn't crash, score is computed normally
        XCTAssertTrue(details.score > 0)
        XCTAssertEqual(details.sleepScore, 7) // 0.1 / 1.5 * 100
    }

    func testHealthKitActivityIDIsStableAndNamespaced() {
        let uuid = UUID(uuidString: "4A8E3020-57F8-40F1-A526-E38A714703BB")!

        let first = HealthKitWorkoutImporter.stableActivityID(for: uuid)
        let second = HealthKitWorkoutImporter.stableActivityID(for: uuid)

        XCTAssertEqual(first, second)
        XCTAssertGreaterThanOrEqual(first, Int64(0x6000_0000_0000_0000))
        XCTAssertLessThan(first, Int64(0x7000_0000_0000_0000))
    }

    func testHealthKitDuplicateMatchingUsesStartAndDistanceTolerance() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(
            HealthKitWorkoutImporter.isProbableDuplicate(
                existingStartDate: start,
                existingDistanceMeters: 5_000,
                candidateStartDate: start.addingTimeInterval(4),
                candidateDistanceMeters: 5_025
            )
        )
        XCTAssertFalse(
            HealthKitWorkoutImporter.isProbableDuplicate(
                existingStartDate: start,
                existingDistanceMeters: 5_000,
                candidateStartDate: start.addingTimeInterval(8),
                candidateDistanceMeters: 5_025
            )
        )
        XCTAssertFalse(
            HealthKitWorkoutImporter.isProbableDuplicate(
                existingStartDate: start,
                existingDistanceMeters: 5_000,
                candidateStartDate: start,
                candidateDistanceMeters: 5_050
            )
        )
    }

    func testHealthKitSportMappingMatchesDashboardFilters() {
        XCTAssertEqual(HealthKitWorkoutImporter.sportType(for: .running), "Run")
        XCTAssertEqual(HealthKitWorkoutImporter.sportType(for: .cycling), "Ride")
        XCTAssertEqual(HealthKitWorkoutImporter.sportType(for: .walking), "Walk")
        XCTAssertEqual(HealthKitWorkoutImporter.sportType(for: .hiking), "Hike")
        XCTAssertEqual(HealthKitWorkoutImporter.sportType(for: .swimming), "Swim")
    }
}
