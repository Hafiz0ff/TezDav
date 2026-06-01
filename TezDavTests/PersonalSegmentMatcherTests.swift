import SwiftData
import XCTest
import CoreLocation
@testable import TezDav

@MainActor
final class PersonalSegmentMatcherTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: Activity.self, ActivityStreamSample.self, PersonalSegment.self, SegmentEffort.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = ModelContext(container)
    }
    
    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }
    
    func testHausdorffDistanceIdenticalPoints() {
        let pathA = [
            CLLocationCoordinate2D(latitude: 38.5000, longitude: 68.5000),
            CLLocationCoordinate2D(latitude: 38.5050, longitude: 68.5050),
            CLLocationCoordinate2D(latitude: 38.5100, longitude: 68.5100)
        ]
        let pathB = [
            CLLocationCoordinate2D(latitude: 38.5000, longitude: 68.5000),
            CLLocationCoordinate2D(latitude: 38.5050, longitude: 68.5050),
            CLLocationCoordinate2D(latitude: 38.5100, longitude: 68.5100)
        ]
        
        let distance = PersonalSegmentMatcher.hausdorffDistance(pathA, pathB)
        XCTAssertLessThan(distance, 1.0) // Virtual 0
    }
    
    func testPersonalSegmentMatchesSuccessfully() throws {
        // 1. Create a Personal Segment
        let segment = PersonalSegment(
            name: "Мой Секретный Трек",
            sportType: "Run",
            distanceMeters: 1000.0,
            startLatitude: 38.5000,
            startLongitude: 68.5000,
            endLatitude: 38.5090,
            endLongitude: 68.5090
        )
        segment.coordinates = [
            CLLocationCoordinate2D(latitude: 38.5000, longitude: 68.5000),
            CLLocationCoordinate2D(latitude: 38.5050, longitude: 68.5050),
            CLLocationCoordinate2D(latitude: 38.5090, longitude: 68.5090)
        ]
        context.insert(segment)
        
        // 2. Create activity and stream samples that cross this segment
        let activity = Activity(
            stravaId: 201,
            sportType: "Run",
            name: "Утренний Бег",
            startDate: Date(),
            distanceMeters: 1200.0,
            movingTime: 300.0,
            elapsedTime: 300.0,
            elevationGain: 10.0,
            trimp: 40.0,
            trainingLoad: 40.0
        )
        context.insert(activity)
        
        let samples = [
            ActivityStreamSample(activityId: 201, offsetSeconds: 0, distanceMeters: 0.0, latitude: 38.4900, longitude: 68.4900),
            // Start of segment
            ActivityStreamSample(activityId: 201, offsetSeconds: 20, distanceMeters: 100.0, latitude: 38.5001, longitude: 68.5001, heartRate: 140.0),
            // Midpoint
            ActivityStreamSample(activityId: 201, offsetSeconds: 120, distanceMeters: 600.0, latitude: 38.5051, longitude: 68.5051, heartRate: 150.0),
            // End of segment
            ActivityStreamSample(activityId: 201, offsetSeconds: 220, distanceMeters: 1100.0, latitude: 38.5089, longitude: 68.5089, heartRate: 160.0),
            ActivityStreamSample(activityId: 201, offsetSeconds: 250, distanceMeters: 1200.0, latitude: 38.5150, longitude: 68.5150)
        ]
        for sample in samples {
            context.insert(sample)
        }
        
        try context.save()
        
        // 3. Match segment
        PersonalSegmentMatcher.matchPersonalSegments(for: activity, samples: samples, context: context)
        
        // 4. Verify effort was created and linked to PersonalSegment
        let efforts = try context.fetch(FetchDescriptor<SegmentEffort>())
        let personalEfforts = efforts.filter { $0.personalSegment != nil }
        
        XCTAssertEqual(personalEfforts.count, 1)
        XCTAssertEqual(personalEfforts.first?.personalSegment?.name, "Мой Секретный Трек")
        XCTAssertEqual(personalEfforts.first?.elapsedTime, 200.0) // 220s - 20s
        XCTAssertEqual(personalEfforts.first?.averageHeartRate, 150.0) // (140 + 150 + 160) / 3
    }
}
