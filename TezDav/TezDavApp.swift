import SwiftData
import SwiftUI

@main
struct TezDavApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(Self.modelContainer)
    }

    static let modelContainer: ModelContainer = {
        do {
            let combinedSchema = Schema([
                Activity.self, ActivityStreamSample.self, SyncState.self, UserSettings.self,
                IntervalSegment.self, TrainingWeek.self, SavedRoute.self, Segment.self,
                SegmentEffort.self, PersonalSegment.self, GearItem.self, WeatherSnapshot.self,
                Achievement.self, FriendActivity.self, FriendComment.self
            ])
            
            if NSClassFromString("XCTestCase") != nil {
                let testConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(for: combinedSchema, configurations: testConfig)
            }
            
            let cloudConfig = ModelConfiguration(
                "TezDavCloud",
                schema: Schema([
                    Activity.self, SyncState.self, UserSettings.self, IntervalSegment.self,
                    TrainingWeek.self, SavedRoute.self, Segment.self, SegmentEffort.self,
                    PersonalSegment.self, GearItem.self, WeatherSnapshot.self, Achievement.self,
                    FriendActivity.self, FriendComment.self
                ]),
                cloudKitDatabase: .private("iCloud.com.example.TezDav")
            )

            
            let localConfig = ModelConfiguration(
                "TezDavLocal",
                schema: Schema([ActivityStreamSample.self]),
                cloudKitDatabase: .none
            )
            
            return try ModelContainer(for: combinedSchema, configurations: [cloudConfig, localConfig])
        } catch {
            preconditionFailure("Unable to create SwiftData container: \(error)")
        }
    }()
}
