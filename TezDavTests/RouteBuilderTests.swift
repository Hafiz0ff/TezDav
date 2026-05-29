import SwiftData
import XCTest
import CoreLocation
@testable import TezDav

@MainActor
final class RouteBuilderTests: XCTestCase {
    func testSavedRouteWaypointsEncodingDecoding() throws {
        let route = SavedRoute(name: "Test Route")
        let waypoints = [
            CLLocationCoordinate2D(latitude: 38.5, longitude: 68.5),
            CLLocationCoordinate2D(latitude: 38.6, longitude: 68.6)
        ]
        route.waypoints = waypoints
        
        let decodedWaypoints = route.waypoints
        XCTAssertEqual(decodedWaypoints.count, 2)
        XCTAssertEqual(decodedWaypoints[0].latitude, 38.5)
        XCTAssertEqual(decodedWaypoints[0].longitude, 68.5)
        XCTAssertEqual(decodedWaypoints[1].latitude, 38.6)
        XCTAssertEqual(decodedWaypoints[1].longitude, 68.6)
    }
    
    func testRouteEngineEstimatedTime() async {
        let routeEngine = RouteEngine()
        routeEngine.totalDistance = 5000 // 5km
        
        // 5:00 min/km = 300 seconds/km
        let estimated = routeEngine.estimatedTime(averagePaceSecPerKm: 300)
        XCTAssertEqual(estimated, 1500) // 25 mins
    }
    
    func testExportRouteToGPX() throws {
        let route = SavedRoute(name: "Morning Loop", sportType: "Run")
        route.waypoints = [
            CLLocationCoordinate2D(latitude: 38.5, longitude: 68.5),
            CLLocationCoordinate2D(latitude: 38.6, longitude: 68.6)
        ]
        route.routeCoordinates = [
            CLLocationCoordinate2D(latitude: 38.5, longitude: 68.5),
            CLLocationCoordinate2D(latitude: 38.55, longitude: 68.55),
            CLLocationCoordinate2D(latitude: 38.6, longitude: 68.6)
        ]
        
        let gpx = ExportManager.exportRouteToGPX(route: route)
        
        XCTAssertTrue(gpx.contains("<name>Morning Loop</name>"))
        XCTAssertTrue(gpx.contains("<rte>"))
        XCTAssertTrue(gpx.contains("<rtept lat=\"38.5\" lon=\"68.5\" />"))
        XCTAssertTrue(gpx.contains("<trk>"))
        XCTAssertTrue(gpx.contains("lat=\"38.55\" lon=\"68.55\""))
    }
}
