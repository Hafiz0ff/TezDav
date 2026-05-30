import XCTest
import SwiftData
@testable import TezDav

final class RunningDynamicsTests: XCTestCase {
    
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
                SyncState.self,
                UserSettings.self,
                TrainingWeek.self,
                SavedRoute.self,
                Segment.self,
                SegmentEffort.self,
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
    
    func testDynamicsZoneClassification() {
        // 1. Cadence zones
        XCTAssertEqual(RunningDynamicsEngine.classifyCadence(182.0), .optimal)
        XCTAssertEqual(RunningDynamicsEngine.classifyCadence(175.0), .good)
        XCTAssertEqual(RunningDynamicsEngine.classifyCadence(164.0), .fair)
        XCTAssertEqual(RunningDynamicsEngine.classifyCadence(155.0), .poor)
        
        // 2. Vertical Oscillation zones
        XCTAssertEqual(RunningDynamicsEngine.classifyVerticalOscillation(5.5), .optimal)
        XCTAssertEqual(RunningDynamicsEngine.classifyVerticalOscillation(7.2), .good)
        XCTAssertEqual(RunningDynamicsEngine.classifyVerticalOscillation(9.0), .fair)
        XCTAssertEqual(RunningDynamicsEngine.classifyVerticalOscillation(11.2), .poor)
        
        // 3. Ground Contact Time zones
        XCTAssertEqual(RunningDynamicsEngine.classifyGCT(190.0), .optimal)
        XCTAssertEqual(RunningDynamicsEngine.classifyGCT(220.0), .good)
        XCTAssertEqual(RunningDynamicsEngine.classifyGCT(260.0), .fair)
        XCTAssertEqual(RunningDynamicsEngine.classifyGCT(310.0), .poor)
        
        // 4. L/R Balance zones
        XCTAssertEqual(RunningDynamicsEngine.classifyLRBalance(50.2), .optimal)
        XCTAssertEqual(RunningDynamicsEngine.classifyLRBalance(49.0), .good)
        XCTAssertEqual(RunningDynamicsEngine.classifyLRBalance(47.5), .poor)
    }
    
    @MainActor
    func testBiomechanicalEnrichment() {
        let now = Date()
        
        // 1. Create a running activity without dynamics fields
        let activity = Activity(
            stravaId: 777,
            sportType: "Run",
            name: "Morning Run",
            startDate: now,
            distanceMeters: 5000.0,
            movingTime: 1200,
            elapsedTime: 1200,
            elevationGain: 50,
            averageHeartRate: 150,
            averagePower: nil,
            averageCadence: 172.0,
            averageSpeed: 4.16, // ~4:00 min/km
            trimp: 30,
            trainingLoad: 35
        )
        context.insert(activity)
        
        // Check initial state
        XCTAssertNil(activity.averageVerticalOscillation)
        XCTAssertNil(activity.averageGroundContactTime)
        XCTAssertNil(activity.averageStrideLength)
        XCTAssertNil(activity.averageLeftGCTPercent)
        
        // 2. Create sample streams representing 10 seconds of running
        var samples: [ActivityStreamSample] = []
        for offset in 0..<10 {
            let sample = ActivityStreamSample(
                activityId: 777,
                offsetSeconds: offset,
                distanceMeters: Double(offset) * 4.16,
                latitude: 38.56 + Double(offset) * 0.0001,
                longitude: 68.82 + Double(offset) * 0.0001,
                heartRate: 150.0,
                cadence: 172.0,
                power: nil,
                speed: 4.16,
                altitude: 800.0
            )
            context.insert(sample)
            samples.append(sample)
        }
        
        // 3. Enrich activity via the engine
        RunningDynamicsEngine.enrich(activity: activity, samples: samples)
        
        // Verify averages are generated
        XCTAssertNotNil(activity.averageVerticalOscillation)
        XCTAssertNotNil(activity.averageGroundContactTime)
        XCTAssertNotNil(activity.averageStrideLength)
        XCTAssertNotNil(activity.averageLeftGCTPercent)
        
        // Stride length should be around speed * 60 / cadence = 4.16 * 60 / 172 = 1.45 meters
        XCTAssertEqual(activity.averageStrideLength!, 1.451, accuracy: 0.01)
        
        // GCT should be around 240 - 15 * (4.16 - 3) = 240 - 17.4 = 222.6 ms
        XCTAssertEqual(activity.averageGroundContactTime!, 222.6, accuracy: 5.0)
        
        // Vertical Oscillation should be around 8.5 - 0.05 * (172 - 170) + (4.16 - 3) * 0.4 = 8.5 - 0.1 + 0.46 = 8.86 cm
        XCTAssertEqual(activity.averageVerticalOscillation!, 8.86, accuracy: 1.0)
        
        // Verify samples are enriched too
        for sample in samples {
            XCTAssertNotNil(sample.strideLength)
            XCTAssertNotNil(sample.verticalOscillation)
            XCTAssertNotNil(sample.groundContactTime)
            XCTAssertNotNil(sample.leftGCTPercent)
        }
        
        // 4. Save and fetch again to verify persistence
        try? context.save()
        
        let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.stravaId == 777 })
        let fetched = try? context.fetch(descriptor).first
        
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.averageStrideLength, activity.averageStrideLength)
        XCTAssertEqual(fetched?.averageVerticalOscillation, activity.averageVerticalOscillation)
        XCTAssertEqual(fetched?.averageGroundContactTime, activity.averageGroundContactTime)
        XCTAssertEqual(fetched?.averageLeftGCTPercent, activity.averageLeftGCTPercent)
    }
}
