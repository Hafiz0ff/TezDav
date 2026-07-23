import SwiftData
import SwiftUI

@MainActor
private enum RedesignPreviewData {
    static let container: ModelContainer = {
        let schema = Schema([
            Activity.self, ActivityStreamSample.self, SyncState.self, UserSettings.self,
            IntervalSegment.self, TrainingWeek.self, SavedRoute.self, Segment.self,
            SegmentEffort.self, PersonalSegment.self, GearItem.self, WeatherSnapshot.self,
            Achievement.self, FriendActivity.self, FriendComment.self, PlannedWorkout.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Unable to create the redesign preview container: \(error)")
        }
    }()
}

@MainActor
private struct RedesignPreviewRoot<Content: View>: View {
    let reduceTransparency: Bool
    private let content: Content

    init(
        reduceTransparency: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.reduceTransparency = reduceTransparency
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackgroundView()
                content
            }
        }
        .modelContainer(RedesignPreviewData.container)
        .environment(\.tezDavReduceTransparencyOverride, reduceTransparency)
        .preferredColorScheme(.dark)
    }
}

#Preview("Главная - Glass") {
    RedesignPreviewRoot(reduceTransparency: false) { DashboardView() }
}

#Preview("Главная - Reduce Transparency") {
    RedesignPreviewRoot(reduceTransparency: true) { DashboardView() }
}

#Preview("Форма - Glass") {
    RedesignPreviewRoot(reduceTransparency: false) { FormView() }
}

#Preview("Форма - Reduce Transparency") {
    RedesignPreviewRoot(reduceTransparency: true) { FormView() }
}

#Preview("Рекорды - Glass") {
    RedesignPreviewRoot(reduceTransparency: false) { RecordsView() }
}

#Preview("Рекорды - Reduce Transparency") {
    RedesignPreviewRoot(reduceTransparency: true) { RecordsView() }
}

#Preview("Карта - Glass") {
    RedesignPreviewRoot(reduceTransparency: false) { RouteListView() }
}

#Preview("Карта - Reduce Transparency") {
    RedesignPreviewRoot(reduceTransparency: true) { RouteListView() }
}

#Preview("Профиль - Glass") {
    RedesignPreviewRoot(reduceTransparency: false) { ProfileView() }
}

#Preview("Профиль - Reduce Transparency") {
    RedesignPreviewRoot(reduceTransparency: true) { ProfileView() }
}
