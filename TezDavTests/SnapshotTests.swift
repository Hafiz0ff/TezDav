import XCTest
import SwiftUI
import SnapshotTesting
import SwiftData
@testable import TezDav

final class SnapshotTests: XCTestCase {

    private static let sharedContainer: ModelContainer = {
        let schema = Schema([
            Activity.self, ActivityStreamSample.self, UserSettings.self, WeatherSnapshot.self,
            GearItem.self, PersonalSegment.self, PlannedWorkout.self, Achievement.self,
            FriendActivity.self, FriendComment.self, SavedRoute.self, Segment.self, SegmentEffort.self,
            TrainingWeek.self, SyncState.self, IntervalSegment.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to initialize snapshot storage: \(error)")
        }
    }()

    var container: ModelContainer!

    override func setUp() {
        super.setUp()
        container = Self.sharedContainer
        let context = ModelContext(container)

        try? context.delete(model: ActivityStreamSample.self)
        try? context.delete(model: IntervalSegment.self)
        try? context.delete(model: SegmentEffort.self)
        try? context.delete(model: Segment.self)
        try? context.delete(model: PersonalSegment.self)
        try? context.delete(model: PlannedWorkout.self)
        try? context.delete(model: TrainingWeek.self)
        try? context.delete(model: SavedRoute.self)
        try? context.delete(model: WeatherSnapshot.self)
        try? context.delete(model: Achievement.self)
        if let friendComments = try? context.fetch(FetchDescriptor<FriendComment>()) {
            friendComments.forEach(context.delete)
        }
        if let friendActivities = try? context.fetch(FetchDescriptor<FriendActivity>()) {
            friendActivities.forEach(context.delete)
        }
        try? context.delete(model: GearItem.self)
        try? context.delete(model: SyncState.self)
        try? context.delete(model: Activity.self)
        try? context.delete(model: UserSettings.self)

        let settings = TestDataFactory.makeUserSettings(appMode: .pro)
        context.insert(settings)
        
        let runAct = TestDataFactory.makeActivity(sportType: "Run", startDate: TestDataFactory.testBaseDate.addingTimeInterval(-86400 * 15), distanceMeters: 5000.0, movingTime: 1800)
        context.insert(runAct)
        
        let rideAct = TestDataFactory.makeActivity(sportType: "Ride", startDate: TestDataFactory.testBaseDate, distanceMeters: 20000.0, movingTime: 3600)
        context.insert(rideAct)
        
        let gear = TestDataFactory.makeGearItem(maxDistanceKm: 700.0, currentDistanceKm: 350.0)
        context.insert(gear)
        
        do {
            try context.save()
        } catch {
            XCTFail("Failed to seed snapshot storage: \(error)")
        }
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
        let shouldRecord = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
        let context = ModelContext(container)
        let embeddedView = view
            .modelContainer(container)
            .environment(\.modelContext, context)
            .environment(\.locale, AppLanguage.locale)
            
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
                    record: shouldRecord,
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
