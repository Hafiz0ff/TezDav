import XCTest
import SwiftData
import AppIntents
@testable import TezDav

final class ShortcutsTests: XCTestCase {
    
    @MainActor
    func testGetFormIntentExecution() async throws {
        let intent = GetFormIntent()
        let result = try await intent.perform()
        
        XCTAssertNotNil(result.value)
        let val = result.value ?? ""
        XCTAssertTrue(val.contains("Readiness") || val.contains("Готовность"))
    }
    
    @MainActor
    func testGetWeeklyStatsIntentExecution() async throws {
        let intent = GetWeeklyStatsIntent()
        let result = try await intent.perform()
        
        XCTAssertNotNil(result.value)
        let val = result.value ?? ""
        XCTAssertTrue(val.contains("week") || val.contains("неделе") || val.contains("неделю"))
    }
    
    @MainActor
    func testGetLastWorkoutIntentExecution() async throws {
        let intent = GetLastWorkoutIntent()
        let result = try await intent.perform()
        
        XCTAssertNotNil(result.value)
    }
    
    @MainActor
    func testGetGearWearIntentExecution() async throws {
        let intent = GetGearWearIntent()
        let result = try await intent.perform()
        
        XCTAssertNotNil(result.value)
    }
    
    @MainActor
    func testImportWorkoutIntentExecution() async throws {
        let intent = ImportWorkoutIntent()
        let _ = try await intent.perform()
        
        // Simply assert successful execution of deep link trigger
        XCTAssertTrue(true)
    }
}
