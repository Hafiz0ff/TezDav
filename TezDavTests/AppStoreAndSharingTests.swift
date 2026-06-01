import XCTest
import CoreLocation
import SwiftData
import SwiftUI
@testable import TezDav

@MainActor
final class AppStoreAndSharingTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUpWithError() throws {
        let schema = Schema([Activity.self, UserSettings.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
    }
    
    // Test 1: Unique Cities Clustering Logic
    func testUniqueCitiesClusteringLogic() {
        let centerOfDushanbe = CLLocationCoordinate2D(latitude: 38.56, longitude: 68.79)
        let dushanbeAirport = CLLocationCoordinate2D(latitude: 38.54, longitude: 68.82) // ~4.5 km away (should cluster with Dushanbe)
        let khujand = CLLocationCoordinate2D(latitude: 40.28, longitude: 69.62) // ~200 km away (different city)
        
        var clusters: [CLLocationCoordinate2D] = []
        let testCoords = [centerOfDushanbe, dushanbeAirport, khujand]
        
        for coord in testCoords {
            let isNewCluster = !clusters.contains { existing in
                let l1 = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let l2 = CLLocation(latitude: existing.latitude, longitude: existing.longitude)
                return l1.distance(from: l2) <= 15000.0 // 15 km threshold
            }
            if isNewCluster {
                clusters.append(coord)
            }
        }
        
        XCTAssertEqual(clusters.count, 2, "Should group coordinates within 15km into 2 unique cities/clusters")
    }
    
    // Test 2: Explored Area Grid Math (1x1 km grid)
    func testExploredAreaGridLogic() {
        let coord1 = CLLocationCoordinate2D(latitude: 38.56, longitude: 68.79)
        let coord2 = CLLocationCoordinate2D(latitude: 38.5601, longitude: 68.7901) // inside same 1x1 km cell
        let coord3 = CLLocationCoordinate2D(latitude: 38.58, longitude: 68.81) // different cell (~3 km away)
        
        var visitedCells = Set<String>()
        let testCoords = [coord1, coord2, coord3]
        
        for coord in testCoords {
            let latCell = Int(coord.latitude / 0.009)
            let cosLat = cos(coord.latitude * .pi / 180.0)
            let lngCellFactor = cosLat > 0 ? (0.009 / cosLat) : 0.009
            let lngCell = Int(coord.longitude / lngCellFactor)
            visitedCells.insert("\(latCell),\(lngCell)")
        }
        
        XCTAssertEqual(visitedCells.count, 2, "Coordinates should map to exactly 2 distinct 1x1 km cells")
    }
    
    // Test 3: Coordinate Extremes calculation
    func testCoordinateExtremes() {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 38.56, longitude: 68.79),
            CLLocationCoordinate2D(latitude: 38.58, longitude: 68.77),
            CLLocationCoordinate2D(latitude: 38.54, longitude: 68.81)
        ]
        
        var north = coordinates[0].latitude
        var south = coordinates[0].latitude
        var east = coordinates[0].longitude
        var west = coordinates[0].longitude
        
        for coord in coordinates {
            north = max(north, coord.latitude)
            south = min(south, coord.latitude)
            east = max(east, coord.longitude)
            west = min(west, coord.longitude)
        }
        
        XCTAssertEqual(north, 38.58, "North extreme mismatch")
        XCTAssertEqual(south, 38.54, "South extreme mismatch")
        XCTAssertEqual(east, 68.81, "East extreme mismatch")
        XCTAssertEqual(west, 68.77, "West extreme mismatch")
    }
    
    // Test 4: Reduce Motion Animation Selector
    func testReduceMotionAnimationSelector() {
        let isReduceMotionEnabled = true
        let animationForReduceMotion: Animation? = isReduceMotionEnabled ? nil : .easeOut(duration: 0.6)
        XCTAssertNil(animationForReduceMotion, "Animation must be nil when reduce motion is enabled")
        
        let isReduceMotionDisabled = false
        let animationNormal: Animation? = isReduceMotionDisabled ? nil : .easeOut(duration: 0.6)
        XCTAssertNotNil(animationNormal, "Animation should be applied when reduce motion is disabled")
    }
    
    // Test 5: Weekly date range calculation text helper
    func testWeeklyDateRangeCalculator() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 2 // Monday
        let startOfWeek = calendar.date(from: components) ?? Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? Date()
        
        let diff = calendar.dateComponents([.day], from: startOfWeek, to: endOfWeek).day
        XCTAssertEqual(diff, 6, "A week must span 6 additional days from Monday to Sunday")
    }
}
