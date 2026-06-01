import XCTest
import SwiftUI
import SnapshotTesting
import SwiftData
@testable import TezDav

final class SnapshotTests: XCTestCase {
    
    var container: ModelContainer!
    
    override func setUp() {
        super.setUp()
        // Initialize an in-memory ModelContainer for snapshot isolation
        let schema = Schema([
            Activity.self, ActivityStreamSample.self, UserSettings.self, WeatherSnapshot.self,
            GearItem.self, PersonalSegment.self, PlannedWorkout.self, Achievement.self,
            FriendActivity.self, FriendComment.self, SavedRoute.self, Segment.self, SegmentEffort.self,
            TrainingWeek.self, SyncState.self, IntervalSegment.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try! ModelContainer(for: schema, configurations: config)
        
        // Populate container with mock data
        let context = ModelContext(container)
        let settings = TestDataFactory.makeUserSettings(appMode: .pro)
        context.insert(settings)
        
        let runAct = TestDataFactory.makeActivity(sportType: "Run", startDate: TestDataFactory.testBaseDate.addingTimeInterval(-86400 * 15), distanceMeters: 5000.0, movingTime: 1800)
        context.insert(runAct)
        
        let rideAct = TestDataFactory.makeActivity(sportType: "Ride", startDate: TestDataFactory.testBaseDate, distanceMeters: 20000.0, movingTime: 3600)
        context.insert(rideAct)
        
        let gear = TestDataFactory.makeGearItem(maxDistanceKm: 700.0, currentDistanceKm: 350.0)
        context.insert(gear)
        
        try! context.save()
    }
    
    override func tearDown() {
        container = nil
        super.tearDown()
    }
    
    // MARK: - Helper Rendering & Assertion Method
    
    private func assertViewSnapshot<V: View>(
        _ view: V,
        named name: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let context = ModelContext(container)
        let embeddedView = view
            .modelContainer(container)
            .environment(\.modelContext, context)
            
        // Test variations: 2 themes x 3 size categories
        let themes: [(String, ColorScheme)] = [("Light", .light), ("Dark", .dark)]
        let fontSizes: [(String, DynamicTypeSize)] = [
            ("XS", .xSmall),
            ("Standard", .medium),
            ("XXL", .accessibility5)
        ]
        
        for (themeName, theme) in themes {
            for (sizeName, size) in fontSizes {
                let testView = embeddedView
                    .preferredColorScheme(theme)
                    .dynamicTypeSize(size)
                    .frame(width: 375, height: 812)
                    .background(theme == .dark ? Color.black : Color.white)
                
                let hostingController = UIHostingController(rootView: testView)
                hostingController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
                
                assertSnapshot(
                    of: hostingController,
                    as: .image(on: .iPhoneX),
                    named: "\(name)_\(themeName)_\(sizeName)",
                    record: false,
                    file: file,
                    testName: "testSnapshot",
                    line: line
                )
            }
        }
    }
    
    // MARK: - Snapshot Coverage Tests
    
    func testDashboardViewSnapshot() {
        assertViewSnapshot(DashboardView(), named: "DashboardView")
    }
    
    func testActivityDetailViewSnapshot() {
        let act = TestDataFactory.makeActivity(sportType: "Run")
        assertViewSnapshot(ActivityDetailView(activity: act), named: "ActivityDetailView")
    }
    func testFormViewSnapshot() {
        let view = FormView()
        assertViewSnapshot(view, named: "FormView")
    }
    
    func testRecordsViewSnapshot() {
        assertViewSnapshot(RecordsView(), named: "RecordsView")
    }
    
    func testProfileViewSnapshot() {
        assertViewSnapshot(ProfileView(), named: "ProfileView")
    }
    
    func testGearViewSnapshot() {
        assertViewSnapshot(GearListView(), named: "GearListView")
    }
    
    func testWeatherAnalyticsViewSnapshot() {
        assertViewSnapshot(WeatherAnalyticsView(), named: "WeatherAnalyticsView")
    }
    
    func testSocialFeedViewSnapshot() {
        assertViewSnapshot(SocialFeedView(), named: "SocialFeedView")
    }
    
    func testOnboardingViewSnapshot() {
        assertViewSnapshot(OnboardingView(isConnected: .constant(true), onboardingCompleted: .constant(false)), named: "OnboardingView")
    }
}
