import XCTest
import SwiftData
@testable import TezDav

final class PerformanceTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Activity.self, ActivityStreamSample.self, UserSettings.self, WeatherSnapshot.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try! ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }
    
    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }
    
    // MARK: - Benchmark Startup Calculations
    
    func testDashboardRecalculation100Activities() {
        let activities = (0..<100).map { i in
            TestDataFactory.makeActivity(
                stravaId: Int64(i),
                startDate: Date().addingTimeInterval(Double(-i) * 86400.0),
                trainingLoad: 80.0
            )
        }
        
        self.measure {
            let summary = DashboardViewModel.summary(from: activities)
            XCTAssertNotNil(summary)
        }
    }
    
    func testDashboardRecalculation1000Activities() {
        let activities = (0..<1000).map { i in
            TestDataFactory.makeActivity(
                stravaId: Int64(i),
                startDate: Date().addingTimeInterval(Double(-i) * 86400.0),
                trainingLoad: 80.0
            )
        }
        
        self.measure {
            let summary = DashboardViewModel.summary(from: activities)
            XCTAssertNotNil(summary)
        }
    }
    
    // MARK: - Benchmark PMC Historical Recalculation
    
    @MainActor
    func testHistoricalRecalculation100Activities() {
        let settings = TestDataFactory.makeUserSettings()
        for i in 0..<100 {
            let act = TestDataFactory.makeActivity(stravaId: Int64(i))
            context.insert(act)
        }
        try! context.save()
        
        self.measure {
            TrainingLoadCalculator.recalculateAllActivities(context: context, settings: settings)
        }
    }
    
    @MainActor
    func testHistoricalRecalculation500Activities() {
        let settings = TestDataFactory.makeUserSettings()
        for i in 0..<500 {
            let act = TestDataFactory.makeActivity(stravaId: Int64(i))
            context.insert(act)
        }
        try! context.save()
        
        self.measure {
            TrainingLoadCalculator.recalculateAllActivities(context: context, settings: settings)
        }
    }
    
    // MARK: - Memory Profiling (XCTMemoryMetric)
    
    func testMemoryMetricDuringSummary() {
        let activities = (0..<500).map { i in
            TestDataFactory.makeActivity(
                stravaId: Int64(i),
                startDate: Date().addingTimeInterval(Double(-i) * 86400.0),
                trainingLoad: 80.0
            )
        }
        
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(metrics: [XCTMemoryMetric()], options: options) {
            _ = DashboardViewModel.summary(from: activities)
        }
    }
}
