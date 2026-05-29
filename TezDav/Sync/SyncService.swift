import Foundation
import SwiftData

@MainActor
final class SyncService {
    private let apiClient: StravaAPIClientProtocol
    private let modelContext: ModelContext
    private let progress: SyncProgress
    private let perPage: Int

    init(apiClient: StravaAPIClientProtocol, modelContext: ModelContext, progress: SyncProgress, perPage: Int = 100) {
        self.apiClient = apiClient
        self.modelContext = modelContext
        self.progress = progress
        self.perPage = perPage
    }

    func importAll(after: Date? = nil) async {
        var page = 1
        var totalImported = 0

        do {
            while true {
                progress.phase = .importing(page: page, imported: totalImported)
                let activities = try await apiClient.activities(page: page, perPage: perPage, after: after)
                if activities.isEmpty {
                    break
                }

                for summary in activities {
                    upsert(summary)
                    totalImported += 1
                }

                if activities.count < perPage {
                    break
                }
                page += 1
            }

            updateSyncState(imported: totalImported, errorMessage: nil)
            try modelContext.save()
            progress.phase = .finished(imported: totalImported)
        } catch {
            updateSyncState(imported: totalImported, errorMessage: String(describing: error))
            try? modelContext.save()
            progress.phase = .failed(String(describing: error))
        }
    }

    private func upsert(_ summary: StravaActivitySummary) {
        let targetId = summary.id
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { activity in
                activity.stravaId == targetId
            }
        )
        let existing = try? modelContext.fetch(descriptor).first
        let input = ActivityMetricInput(
            date: summary.startDate,
            duration: TimeInterval(summary.movingTime),
            distanceMeters: summary.distance,
            averageHeartRate: summary.averageHeartrate,
            averagePower: summary.averageWatts,
            sportType: summary.sportType
        )
        let trimp = TrainingLoadCalculator.trimp(duration: input.duration, averageHeartRate: input.averageHeartRate, maxHeartRate: 190)
        let load = TrainingLoadCalculator.activityLoad(input)

        if let existing {
            existing.name = summary.name
            existing.sportType = summary.sportType
            existing.startDate = summary.startDate
            existing.distanceMeters = summary.distance
            existing.movingTime = TimeInterval(summary.movingTime)
            existing.elapsedTime = TimeInterval(summary.elapsedTime)
            existing.elevationGain = summary.totalElevationGain
            existing.averageHeartRate = summary.averageHeartrate
            existing.averagePower = summary.averageWatts
            existing.averageCadence = summary.averageCadence
            existing.averageSpeed = summary.averageSpeed
            existing.encodedPolyline = summary.map?.summaryPolyline
            existing.trimp = trimp
            existing.trainingLoad = load
            existing.importedAt = .now
        } else {
            modelContext.insert(Activity(
                stravaId: summary.id,
                sportType: summary.sportType,
                name: summary.name,
                startDate: summary.startDate,
                distanceMeters: summary.distance,
                movingTime: TimeInterval(summary.movingTime),
                elapsedTime: TimeInterval(summary.elapsedTime),
                elevationGain: summary.totalElevationGain,
                averageHeartRate: summary.averageHeartrate,
                averagePower: summary.averageWatts,
                averageCadence: summary.averageCadence,
                averageSpeed: summary.averageSpeed,
                encodedPolyline: summary.map?.summaryPolyline,
                trimp: trimp,
                trainingLoad: load
            ))
        }
    }

    private func updateSyncState(imported: Int, errorMessage: String?) {
        let descriptor = FetchDescriptor<SyncState>(
            predicate: #Predicate { state in
                state.key == "strava"
            }
        )
        let state = (try? modelContext.fetch(descriptor).first) ?? SyncState()
        if state.modelContext == nil {
            modelContext.insert(state)
        }
        state.lastSuccessfulSync = errorMessage == nil ? .now : state.lastSuccessfulSync
        state.importedActivityCount += imported
        state.lastErrorMessage = errorMessage
    }
}
