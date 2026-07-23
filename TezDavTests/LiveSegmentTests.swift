import SwiftData
import XCTest
import CoreLocation
@testable import TezDav

@MainActor
final class LiveSegmentTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: Segment.self, SegmentEffort.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = ModelContext(container)
        
        // Reset the singleton state
        LiveSegmentCoordinator.shared.reset()
    }
    
    override func tearDown() {
        LiveSegmentCoordinator.shared.reset()
        context = nil
        container = nil
        super.tearDown()
    }
    
    func testLiveSegmentProximityDetectionAndStart() throws {
        // 1. Create and insert a segment
        let segment = Segment(
            name: "Спринт на Рудаки Тест",
            sportType: "Run",
            distanceMeters: 500.0,
            averageGrade: 0.5,
            elevationGain: 2.0,
            startLatitude: 38.5739,
            startLongitude: 68.7979,
            endLatitude: 38.5784,
            endLongitude: 68.7973
        )
        segment.coordinates = [
            CLLocationCoordinate2D(latitude: 38.5739, longitude: 68.7979),
            CLLocationCoordinate2D(latitude: 38.5784, longitude: 68.7973)
        ]
        context.insert(segment)
        try context.save()
        
        let coordinator = LiveSegmentCoordinator.shared
        
        // 2. Telemetry update far away from start -> should not start
        coordinator.updateLocation(
            latitude: 38.5000,
            longitude: 68.5000,
            workoutDistance: 0.0,
            elapsedSeconds: 0,
            sportType: "Run",
            context: context
        )
        
        XCTAssertFalse(coordinator.isInsideSegment)
        XCTAssertNil(coordinator.activeSegment)
        
        // 3. Telemetry update near start -> should start segment
        coordinator.updateLocation(
            latitude: 38.57391, // extremely close
            longitude: 68.79791,
            workoutDistance: 100.0,
            elapsedSeconds: 30,
            sportType: "Run",
            context: context
        )
        
        XCTAssertTrue(coordinator.isInsideSegment)
        XCTAssertEqual(coordinator.activeSegment?.name, "Спринт на Рудаки Тест")
        XCTAssertEqual(coordinator.distanceRemaining, 500.0)
    }
    
    func testLiveSegmentSnappingAndTimeGapCalculation() throws {
        // 1. Create segment with 10 coordinate points
        let segment = Segment(
            name: "Подъем Амфитеатр Тест",
            sportType: "Run",
            distanceMeters: 900.0,
            averageGrade: 4.0,
            elevationGain: 36.0,
            startLatitude: 38.5830,
            startLongitude: 68.7845,
            endLatitude: 38.5910,
            endLongitude: 68.7780
        )
        
        // Generate 10 points
        var points: [CLLocationCoordinate2D] = []
        for i in 0..<10 {
            let t = Double(i) / 9.0
            let lat = 38.5830 + (38.5910 - 38.5830) * t
            let lon = 68.7845 + (68.7780 - 68.7845) * t
            points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        segment.coordinates = points
        context.insert(segment)
        
        // Insert a leader KOM bot effort (90 seconds elapsed time)
        let leaderEffort = SegmentEffort(
            athleteName: "Бот Лидер",
            startDate: Date(),
            elapsedTime: 90.0,
            averageHeartRate: 170,
            averagePower: nil,
            averageSpeed: 10.0,
            isMock: true
        )
        leaderEffort.segment = segment
        context.insert(leaderEffort)
        segment.efforts.append(leaderEffort)
        try context.save()
        
        let coordinator = LiveSegmentCoordinator.shared
        
        // 2. Enter segment at t = 10s
        coordinator.updateLocation(
            latitude: points[0].latitude,
            longitude: points[0].longitude,
            workoutDistance: 50.0,
            elapsedSeconds: 10,
            sportType: "Run",
            context: context
        )
        
        XCTAssertTrue(coordinator.isInsideSegment)
        XCTAssertEqual(coordinator.targetTime, 90.0)
        
        // 3. Move to index 3 (3/9 = 33.3% progress) at t = 30s (20s on segment)
        // Target time to index 3 is: 90s * (3/9) = 30s.
        // User actual time on segment is: 30s - 10s = 20s.
        // Gap is: 20s - 30s = -10s (user is 10s ahead!)
        coordinator.updateLocation(
            latitude: points[3].latitude,
            longitude: points[3].longitude,
            workoutDistance: 350.0,
            elapsedSeconds: 30,
            sportType: "Run",
            context: context
        )
        
        XCTAssertEqual(coordinator.segmentProgress, 3.0 / 9.0, accuracy: 0.01)
        XCTAssertEqual(coordinator.distanceCovered, 300.0, accuracy: 1.0)
        XCTAssertEqual(coordinator.distanceRemaining, 600.0, accuracy: 1.0)
        XCTAssertEqual(coordinator.timeAheadBehind, -10.0, accuracy: 0.1)
    }
    
    func testLiveSegmentCompletionAndEffortSaving() throws {
        // 1. Create and insert a segment
        let segment = Segment(
            name: "Спринт Конец Тест",
            sportType: "Run",
            distanceMeters: 300.0,
            averageGrade: 0.0,
            elevationGain: 0.0,
            startLatitude: 38.5700,
            startLongitude: 68.7900,
            endLatitude: 38.5730,
            endLongitude: 68.7930
        )
        segment.coordinates = [
            CLLocationCoordinate2D(latitude: 38.5700, longitude: 68.7900),
            CLLocationCoordinate2D(latitude: 38.5715, longitude: 68.7915),
            CLLocationCoordinate2D(latitude: 38.5730, longitude: 68.7930)
        ]
        context.insert(segment)
        try context.save()
        
        let coordinator = LiveSegmentCoordinator.shared
        
        // 2. Enter segment
        coordinator.updateLocation(
            latitude: 38.5700,
            longitude: 68.7900,
            workoutDistance: 10.0,
            elapsedSeconds: 5,
            sportType: "Run",
            context: context
        )
        XCTAssertTrue(coordinator.isInsideSegment)
        
        // 3. Complete segment (reached end coordinate) at t = 25s (20s duration)
        coordinator.updateLocation(
            latitude: 38.5730,
            longitude: 68.7930,
            workoutDistance: 310.0,
            elapsedSeconds: 25,
            sportType: "Run",
            context: context
        )
        
        // Verify completion triggers
        XCTAssertFalse(coordinator.isInsideSegment)
        XCTAssertTrue(coordinator.segmentCompleted)
        XCTAssertEqual(coordinator.elapsedSegmentTime, 20.0)
        
        // Verify effort saved in SwiftData database
        let descriptor = FetchDescriptor<SegmentEffort>()
        let efforts = try context.fetch(descriptor)
        let userEfforts = efforts.filter { !$0.isMock }
        
        XCTAssertEqual(userEfforts.count, 1)
        XCTAssertEqual(userEfforts.first?.elapsedTime, 20.0)
        XCTAssertEqual(userEfforts.first?.segment?.name, "Спринт Конец Тест")
    }
}
