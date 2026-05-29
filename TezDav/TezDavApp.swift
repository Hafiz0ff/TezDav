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
            return try ModelContainer(for: Activity.self, ActivityStreamSample.self, SyncState.self, UserSettings.self, IntervalSegment.self, TrainingWeek.self, SavedRoute.self, Segment.self, SegmentEffort.self)
        } catch {
            preconditionFailure("Unable to create SwiftData container: \(error)")
        }
    }()
}
