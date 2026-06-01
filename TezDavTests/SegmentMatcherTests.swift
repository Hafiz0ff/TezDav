import SwiftData
import XCTest
import CoreLocation
@testable import TezDav

@MainActor
final class SegmentMatcherTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: Activity.self, ActivityStreamSample.self, Segment.self, SegmentEffort.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = ModelContext(container)
    }
    
    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }
    
    func testSegmentEffortCreatedWhenTrackMatchesSegment() throws {
        // 1. Create a segment
        let segment = Segment(
            name: "Подъем Рудаки",
            sportType: "Run",
            distanceMeters: 1000.0,
            averageGrade: 2.0,
            elevationGain: 20.0,
            startLatitude: 38.5000,
            startLongitude: 68.5000,
            endLatitude: 38.5090,
            endLongitude: 68.5090
        )
        context.insert(segment)
        
        // 2. Create activity and stream samples that cross the segment
        let activity = Activity(
            stravaId: 101,
            sportType: "Run",
            name: "Утренняя тренировка",
            startDate: Date(),
            distanceMeters: 1200.0,
            movingTime: 300.0,
            elapsedTime: 300.0,
            elevationGain: 20.0,
            trimp: 50.0,
            trainingLoad: 50.0
        )
        context.insert(activity)
        
        let samples = [
            // Start of workout - far away
            ActivityStreamSample(activityId: 101, offsetSeconds: 0, distanceMeters: 0.0, latitude: 38.4900, longitude: 68.4900),
            // Enters segment start
            ActivityStreamSample(activityId: 101, offsetSeconds: 20, distanceMeters: 100.0, latitude: 38.5001, longitude: 68.5001, heartRate: 150.0),
            // Middle of segment
            ActivityStreamSample(activityId: 101, offsetSeconds: 120, distanceMeters: 600.0, latitude: 38.5045, longitude: 68.5045, heartRate: 160.0),
            // Exits segment end
            ActivityStreamSample(activityId: 101, offsetSeconds: 220, distanceMeters: 1100.0, latitude: 38.5089, longitude: 68.5089, heartRate: 170.0),
            // End of workout - far away
            ActivityStreamSample(activityId: 101, offsetSeconds: 250, distanceMeters: 1200.0, latitude: 38.5150, longitude: 68.5150)
        ]
        for sample in samples {
            context.insert(sample)
        }
        
        try context.save()
        
        // 3. Match segments
        SegmentMatcher.matchSegments(for: activity, samples: samples, context: context)
        
        // 4. Verify effort was created
        let efforts = try context.fetch(FetchDescriptor<SegmentEffort>())
        let userEfforts = efforts.filter { !$0.isMock }
        
        XCTAssertEqual(userEfforts.count, 1)
        XCTAssertEqual(userEfforts.first?.segment?.name, "Подъем Рудаки")
        XCTAssertEqual(userEfforts.first?.elapsedTime, 200.0) // 220s - 20s = 200s
        XCTAssertEqual(userEfforts.first?.averageHeartRate, 160.0) // (150 + 160 + 170) / 3 = 160
    }
    
    func testSegmentEffortNotCreatedWhenTrackFailsDistanceTolerance() throws {
        // 1. Create a segment
        let segment = Segment(
            name: "Подъем Рудаки",
            sportType: "Run",
            distanceMeters: 1000.0,
            averageGrade: 2.0,
            elevationGain: 20.0,
            startLatitude: 38.5000,
            startLongitude: 68.5000,
            endLatitude: 38.5090,
            endLongitude: 68.5090
        )
        context.insert(segment)
        
        // 2. Create activity where the user takes a huge detour inside the segment
        // making the real distance traveled 1500m (detour of +50%), which exceeds 15% tolerance.
        let activity = Activity(
            stravaId: 102,
            sportType: "Run",
            name: "Тренировка с петлей",
            startDate: Date(),
            distanceMeters: 2000.0,
            movingTime: 600.0,
            elapsedTime: 600.0,
            elevationGain: 20.0,
            trimp: 50.0,
            trainingLoad: 50.0
        )
        context.insert(activity)
        
        let samples = [
            ActivityStreamSample(activityId: 102, offsetSeconds: 20, distanceMeters: 100.0, latitude: 38.5001, longitude: 68.5001),
            ActivityStreamSample(activityId: 102, offsetSeconds: 300, distanceMeters: 1600.0, latitude: 38.5089, longitude: 68.5089)
        ]
        for sample in samples {
            context.insert(sample)
        }
        try context.save()
        
        SegmentMatcher.matchSegments(for: activity, samples: samples, context: context)
        
        let efforts = try context.fetch(FetchDescriptor<SegmentEffort>())
        let userEfforts = efforts.filter { !$0.isMock }
        XCTAssertEqual(userEfforts.count, 0, "Effort should not be created due to distance mismatch (+50% difference)")
    }
    
    func testSegmentEffortNotCreatedWhenTrackGoesWrongDirection() throws {
        // 1. Create a segment
        let segment = Segment(
            name: "Подъем Рудаки",
            sportType: "Run",
            distanceMeters: 1000.0,
            averageGrade: 2.0,
            elevationGain: 20.0,
            startLatitude: 38.5000,
            startLongitude: 68.5000,
            endLatitude: 38.5090,
            endLongitude: 68.5090
        )
        context.insert(segment)
        
        // 2. Create activity going backward (from end to start)
        let activity = Activity(
            stravaId: 103,
            sportType: "Run",
            name: "Обратный бег",
            startDate: Date(),
            distanceMeters: 1200.0,
            movingTime: 300.0,
            elapsedTime: 300.0,
            elevationGain: 20.0,
            trimp: 50.0,
            trainingLoad: 50.0
        )
        context.insert(activity)
        
        let samples = [
            // Reaches segment end first (38.5089, 68.5089)
            ActivityStreamSample(activityId: 103, offsetSeconds: 20, distanceMeters: 100.0, latitude: 38.5089, longitude: 68.5089),
            // Reaches segment start last (38.5001, 68.5001)
            ActivityStreamSample(activityId: 103, offsetSeconds: 220, distanceMeters: 1100.0, latitude: 38.5001, longitude: 68.5001)
        ]
        for sample in samples {
            context.insert(sample)
        }
        try context.save()
        
        SegmentMatcher.matchSegments(for: activity, samples: samples, context: context)
        
        let efforts = try context.fetch(FetchDescriptor<SegmentEffort>())
        let userEfforts = efforts.filter { !$0.isMock }
        XCTAssertEqual(userEfforts.count, 0, "Effort should not be created when running in backward direction")
    }
}
