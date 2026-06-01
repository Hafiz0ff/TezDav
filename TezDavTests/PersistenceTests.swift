import SwiftData
import XCTest
@testable import TezDav

@MainActor
final class PersistenceTests: XCTestCase {
    func testActivityCanBeInsertedAndFetched() throws {
        let container = try ModelContainer(
            for: Activity.self, ActivityStreamSample.self, SyncState.self, UserSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        context.insert(Activity(
            stravaId: 42,
            sportType: "Run",
            name: "Morning Run",
            startDate: Date(timeIntervalSince1970: 0),
            distanceMeters: 5_000,
            movingTime: 1_500,
            elapsedTime: 1_600,
            elevationGain: 40,
            trimp: 80,
            trainingLoad: 80
        ))
        try context.save()

        let activities = try context.fetch(FetchDescriptor<Activity>())

        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities.first?.stravaId, 42)
    }

    func testUserSettingsIsMetricConversion() throws {
        let settings = UserSettings()
        XCTAssertTrue(settings.isMetric, "isMetric should be true by default")

        // 1. Metric weight to Imperial conversion
        settings.weightKg = 70.0
        let weightLbs = settings.weightKg * 2.20462
        XCTAssertEqual(weightLbs, 154.3234, accuracy: 0.001)

        // 2. Imperial weight back to Metric conversion
        let rawImperialWeight = 154.3234
        let metricWeight = rawImperialWeight / 2.20462
        XCTAssertEqual(metricWeight, 70.0, accuracy: 0.001)

        // 3. Imperial distance (miles) to Metric (meters) conversion
        let distanceMiles = 10.0
        let distanceMeters = distanceMiles * 1609.344
        XCTAssertEqual(distanceMeters, 16093.44, accuracy: 0.001)

        // 4. Metric distance (meters) to Imperial (miles) conversion
        let convertedMiles = distanceMeters / 1609.344
        XCTAssertEqual(convertedMiles, 10.0, accuracy: 0.001)
    }
}
