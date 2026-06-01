import SwiftData
import XCTest
@testable import TezDav

@MainActor
final class SyncServiceTests: XCTestCase {
    func testImportAllSavesActivitiesAndProgress() async throws {
        let container = try ModelContainer(
            for: Activity.self, ActivityStreamSample.self, SyncState.self, UserSettings.self,
            WeatherSnapshot.self, GearItem.self, Achievement.self, PlannedWorkout.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        let progress = SyncProgress()
        let api = MockStravaAPI(pages: [
            [
                StravaActivitySummary(
                    id: 1,
                    name: "Run",
                    sportType: "Run",
                    startDate: Date(timeIntervalSince1970: 0),
                    distance: 5_000,
                    movingTime: 1_500,
                    elapsedTime: 1_600,
                    totalElevationGain: 20,
                    averageHeartrate: 145,
                    averageWatts: nil,
                    averageCadence: 82,
                    averageSpeed: 3.3,
                    map: StravaMap(summaryPolyline: "abc")
                ),
                StravaActivitySummary(
                    id: 2,
                    name: "Ride",
                    sportType: "Ride",
                    startDate: Date(timeIntervalSince1970: 86_400),
                    distance: 30_000,
                    movingTime: 3_600,
                    elapsedTime: 3_800,
                    totalElevationGain: 100,
                    averageHeartrate: nil,
                    averageWatts: 180,
                    averageCadence: 90,
                    averageSpeed: 8.3,
                    map: nil
                )
            ],
            []
        ])
        let service = SyncService(apiClient: api, modelContext: context, progress: progress, perPage: 2)

        await service.importAll()

        let activities = try context.fetch(FetchDescriptor<Activity>())
        XCTAssertEqual(activities.count, 2)
        XCTAssertEqual(progress.phase, .finished(imported: 2))
    }
}

private struct MockStravaAPI: StravaAPIClientProtocol {
    let pages: [[StravaActivitySummary]]

    func activities(page: Int, perPage: Int, after: Date?) async throws -> [StravaActivitySummary] {
        pages.indices.contains(page - 1) ? pages[page - 1] : []
    }

    func streams(activityId: Int64) async throws -> StravaStreamSet? {
        nil
    }

    func athlete() async throws -> StravaAthlete {
        StravaAthlete(id: 123, firstname: "Test", lastname: "User", profile: nil)
    }
}
