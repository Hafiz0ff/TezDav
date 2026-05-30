import XCTest
import SwiftData
import CoreLocation
@testable import TezDav

final class RouteMatcherTests: XCTestCase {
    
    private var modelContainer: ModelContainer!
    private var context: ModelContext!
    
    @MainActor
    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            modelContainer = try ModelContainer(
                for: Activity.self,
                ActivityStreamSample.self,
                SavedRoute.self,
                configurations: config
            )
            context = modelContainer.mainContext
        } catch {
            XCTFail("Failed to initialize in-memory container: \(error)")
        }
    }
    
    override func tearDown() {
        context = nil
        modelContainer = nil
        super.tearDown()
    }
    
    func testHaversineDistance() {
        // Distance between two points in Dushanbe
        // Point A: 38.560, 68.820
        // Point B: 38.561, 68.820 (approx 111 meters north)
        let dist = RouteMatcher.haversineDistance(lat1: 38.560, lon1: 68.820, lat2: 38.561, lon2: 68.820)
        XCTAssertEqual(dist, 111.1, accuracy: 5.0)
    }
    
    @MainActor
    func testRouteMatcherPerfectMatch() {
        var routeCoords: [CLLocationCoordinate2D] = []
        for i in 0..<15 {
            let pct = Double(i) / 14.0
            routeCoords.append(CLLocationCoordinate2D(latitude: 38.560 + pct * 0.004, longitude: 68.820 + pct * 0.004))
        }
        let routeCoordsData = try! JSONEncoder().encode(routeCoords.map { CodableCoordinate($0) })
        let route = SavedRoute(
            id: UUID(),
            name: "Test Run Route",
            sportType: "Run",
            totalDistanceMeters: 1000.0,
            totalElevationGain: 15.0,
            routeCoordinatesData: routeCoordsData
        )
        context.insert(route)
        
        // 2. Create activity with samples perfectly tracking the route
        let activity = Activity(
            stravaId: 201,
            sportType: "Run",
            name: "Morning Run by plan",
            startDate: Date(),
            distanceMeters: 1000.0,
            movingTime: 300,
            elapsedTime: 300,
            elevationGain: 15.0,
            trimp: 0.0,
            trainingLoad: 0.0
        )
        context.insert(activity)
        
        var samples: [ActivityStreamSample] = []
        for i in 0..<15 {
            let pct = Double(i) / 14.0
            let lat = 38.560 + pct * 0.004
            let lon = 68.820 + pct * 0.004
            let sample = ActivityStreamSample(
                activityId: 201,
                offsetSeconds: i * 20,
                distanceMeters: pct * 1000.0,
                latitude: lat,
                longitude: lon
            )
            samples.append(sample)
        }
        
        // Match!
        RouteMatcher.matchRoute(for: activity, samples: samples, context: context)
        
        XCTAssertTrue(activity.isPlanned)
        XCTAssertEqual(activity.plannedRouteId, route.id)
    }
    
    @MainActor
    func testRouteMatcherTooFarNoMatch() {
        // 1. Create a planned route in Dushanbe
        let routeCoords = [
            CLLocationCoordinate2D(latitude: 38.560, longitude: 68.820),
            CLLocationCoordinate2D(latitude: 38.562, longitude: 68.822)
        ]
        let routeCoordsData = try! JSONEncoder().encode(routeCoords.map { CodableCoordinate($0) })
        let route = SavedRoute(
            id: UUID(),
            name: "Short Trail",
            sportType: "Run",
            totalDistanceMeters: 500.0,
            totalElevationGain: 5.0,
            routeCoordinatesData: routeCoordsData
        )
        context.insert(route)
        
        // 2. Create activity far away (e.g. latitude shifted by 0.01 degree ~ 1.1 km)
        let activity = Activity(
            stravaId: 202,
            sportType: "Run",
            name: "Far Away Run",
            startDate: Date(),
            distanceMeters: 500.0,
            movingTime: 200,
            elapsedTime: 200,
            elevationGain: 5.0,
            trimp: 0.0,
            trainingLoad: 0.0
        )
        context.insert(activity)
        
        var samples: [ActivityStreamSample] = []
        for i in 0..<12 {
            let pct = Double(i) / 11.0
            let lat = 38.570 + pct * 0.002 // Shifted north by 0.01 degree (~1.1km)
            let lon = 68.820 + pct * 0.002
            let sample = ActivityStreamSample(
                activityId: 202,
                offsetSeconds: i * 20,
                distanceMeters: pct * 500.0,
                latitude: lat,
                longitude: lon
            )
            samples.append(sample)
        }
        
        RouteMatcher.matchRoute(for: activity, samples: samples, context: context)
        
        XCTAssertFalse(activity.isPlanned)
        XCTAssertNil(activity.plannedRouteId)
    }
}
