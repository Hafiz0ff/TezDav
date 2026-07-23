import Foundation
import SwiftData
import CoreLocation

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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func importAll(after: Date? = nil) async {
        var page = 1
        var totalImported = 0
        var newlyImportedWorkout: Activity? = nil

        // Start Live Activity
        LiveActivityManager.shared.startSyncActivity(totalCount: 100)

        do {
            while true {
                progress.phase = .importing(page: page, imported: totalImported)
                let activities = try await apiClient.activities(page: page, perPage: perPage, after: after)
                if activities.isEmpty {
                    break
                }

                for summary in activities {
                    let isNew = upsert(summary)
                    totalImported += 1
                    
                    if isNew {
                        let endDate = summary.startDate.addingTimeInterval(TimeInterval(summary.movingTime))
                        let timeSinceEnd = Date.now.timeIntervalSince(endDate)
                        if timeSinceEnd >= 0 && timeSinceEnd <= 2.0 * 3600.0 {
                            let targetId = summary.id
                            let descriptor = FetchDescriptor<Activity>(
                                predicate: #Predicate { $0.stravaId == targetId }
                            )
                            if let act = try? modelContext.fetch(descriptor).first {
                                newlyImportedWorkout = act
                            }
                        }
                    }
                    
                    LiveActivityManager.shared.updateSyncProgress(loadedCount: totalImported, totalCount: max(totalImported + 1, page * perPage))
                }

                if activities.count < perPage {
                    break
                }
                page += 1
            }

            updateSyncState(imported: totalImported, errorMessage: nil)
            try modelContext.save()
            
            // Trigger weather fetching for all newly imported activities
            if !isRunningTests {
                let activitiesDescriptor = FetchDescriptor<Activity>()
                if let allAct = try? modelContext.fetch(activitiesDescriptor) {
                    await WeatherService.shared.fetchWeather(for: allAct, context: modelContext)
                    CoreSpotlightManager.shared.indexActivities(allAct)
                    
                    let userSettingsDescriptor = FetchDescriptor<UserSettings>()
                    let settings = (try? modelContext.fetch(userSettingsDescriptor).first) ?? UserSettings()
                    AchievementManager.shared.scanAndAwardAchievements(context: modelContext, activities: allAct, settings: settings)
                }
            }
            
            progress.phase = .finished(imported: totalImported)
            
            // End Live Activity
            LiveActivityManager.shared.endSyncActivity()
            
            // Show workout summary if any
            if let workout = newlyImportedWorkout {
                LiveActivityManager.shared.showWorkoutSummary(
                    name: workout.name,
                    sportType: workout.sportType,
                    distance: workout.distanceMeters,
                    duration: workout.movingTime,
                    load: workout.trainingLoad
                )
            }
        } catch {
            updateSyncState(imported: totalImported, errorMessage: String(describing: error))
            try? modelContext.save()
            progress.phase = .failed(String(describing: error))
            
            // End Live Activity
            LiveActivityManager.shared.endSyncActivity()
        }
    }

    @discardableResult
    private func upsert(_ summary: StravaActivitySummary) -> Bool {
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

        let startLat = (summary.startLatlng?.count ?? 0) >= 2 ? summary.startLatlng?[0] : nil
        let startLon = (summary.startLatlng?.count ?? 0) >= 2 ? summary.startLatlng?[1] : nil

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
            existing.startLatitude = startLat
            existing.startLongitude = startLon
            assignGear(to: existing, gearId: summary.gearId, sportType: summary.sportType)
            return false
        } else {
            let newActivity = Activity(
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
                trainingLoad: load,
                startLatitude: startLat,
                startLongitude: startLon
            )
            modelContext.insert(newActivity)
            assignGear(to: newActivity, gearId: summary.gearId, sportType: summary.sportType)
            return true
        }
    }

    private func assignGear(to activity: Activity, gearId: String?, sportType: String) {
        let descriptor = FetchDescriptor<GearItem>()
        guard let gears = try? modelContext.fetch(descriptor) else { return }
        
        if let gId = gearId, let match = gears.first(where: { $0.stravaGearId == gId }) {
            activity.gearItem = match
            recalculateGearMileage(gears)
            return
        }
        
        let normSport = sportType.lowercased()
        let targetType = normSport.contains("ride") || normSport.contains("cycl") ? "Ride" : "Run"
        
        if let defaultGear = gears.first(where: { $0.isActive && $0.sportType == targetType }) {
            activity.gearItem = defaultGear
            recalculateGearMileage(gears)
        }
    }
    
    private func recalculateGearMileage(_ gears: [GearItem]) {
        for gear in gears {
            let totalMeters = gear.activities.reduce(0.0) { $0 + $1.distanceMeters }
            gear.currentDistanceKm = totalMeters / 1000.0
            checkGearAlert(gear)
        }
    }
    
    private func checkGearAlert(_ gear: GearItem) {
        let limit = gear.maxDistanceKm
        let remaining = limit - gear.currentDistanceKm
        if gear.isActive && remaining > 0 && remaining <= 50.0 {
            NotificationManager.shared.sendNotification(
                title: AppLanguage.isRussian ? "Замена экипировки" : "Gear Replacement Alert",
                body: String(format: AppLanguage.isRussian ? "Ресурс экипировки %@ (%d км). Осталось всего %.1f км. Рекомендуется замена." : "Gear limit reached for %@ (%d km). Only %.1f km remaining. Replacement advised.", gear.name, Int(limit), remaining),
                userInfo: [:]
            )
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
    
    static func seedFriendActivitiesIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<FriendActivity>()
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return // Already seeded
        }
        
        // 1. Daler K (Ride)
        let dalerCoords = [
            CLLocationCoordinate2D(latitude: 38.56, longitude: 68.79),
            CLLocationCoordinate2D(latitude: 38.60, longitude: 68.79),
            CLLocationCoordinate2D(latitude: 38.65, longitude: 68.78),
            CLLocationCoordinate2D(latitude: 38.70, longitude: 68.78)
        ]
        let dalerPoly = PolylineEncoder.encode(coordinates: dalerCoords)
        let dalerAct = FriendActivity(
            friendName: "Далер К.",
            friendAvatar: "ДК",
            sportType: "Ride",
            title: "Варзобское ущелье — подъем к ГЭС",
            distanceMeters: 34200.0,
            durationSeconds: 6300.0,
            startDate: Date().addingTimeInterval(-3.0 * 3600.0), // 3 hours ago
            encodedPolyline: dalerPoly,
            kudosCount: 18,
            hasKudosByMe: false
        )
        
        // Comments for Daler
        let comment1 = FriendComment(authorName: "Алекс М.", text: "Отличный подъем! Какой градиент на последнем километре?", createdAt: Date().addingTimeInterval(-2.5 * 3600.0))
        let comment2 = FriendComment(authorName: "Мария С.", text: "Ух, мощный средний темп! 🚴‍♂️🔥", createdAt: Date().addingTimeInterval(-2.0 * 3600.0))
        dalerAct.comments.append(comment1)
        dalerAct.comments.append(comment2)
        context.insert(dalerAct)
        
        // 2. Maria S (Run)
        let mariaCoords = [
            CLLocationCoordinate2D(latitude: 38.58, longitude: 68.79),
            CLLocationCoordinate2D(latitude: 38.582, longitude: 68.792),
            CLLocationCoordinate2D(latitude: 38.584, longitude: 68.791),
            CLLocationCoordinate2D(latitude: 38.58, longitude: 68.788),
            CLLocationCoordinate2D(latitude: 38.58, longitude: 68.79)
        ]
        let mariaPoly = PolylineEncoder.encode(coordinates: mariaCoords)
        let mariaAct = FriendActivity(
            friendName: "Мария С.",
            friendAvatar: "МС",
            sportType: "Run",
            title: "Темповая тренировка в Ботаническом саду",
            distanceMeters: 5400.0,
            durationSeconds: 1572.0, // 26m 12s
            startDate: Date().addingTimeInterval(-5.0 * 3600.0), // 5 hours ago
            encodedPolyline: mariaPoly,
            kudosCount: 12,
            hasKudosByMe: true
        )
        
        let comment3 = FriendComment(authorName: "Далер К.", text: "Прекрасный каденс, держишь планку! 👍", createdAt: Date().addingTimeInterval(-4.0 * 3600.0))
        mariaAct.comments.append(comment3)
        context.insert(mariaAct)
        
        // 3. Alex M (Walk)
        let alexCoords = [
            CLLocationCoordinate2D(latitude: 38.55, longitude: 68.80),
            CLLocationCoordinate2D(latitude: 38.552, longitude: 68.802),
            CLLocationCoordinate2D(latitude: 38.555, longitude: 68.801),
            CLLocationCoordinate2D(latitude: 38.55, longitude: 68.80)
        ]
        let alexPoly = PolylineEncoder.encode(coordinates: alexCoords)
        let alexAct = FriendActivity(
            friendName: "Алекс М.",
            friendAvatar: "АМ",
            sportType: "Walk",
            title: "Вечерний променад, парк Куруши Кабир",
            distanceMeters: 3800.0,
            durationSeconds: 2700.0, // 45 mins
            startDate: Date().addingTimeInterval(-1.0 * 3600.0), // 1 hour ago
            encodedPolyline: alexPoly,
            kudosCount: 4,
            hasKudosByMe: false
        )
        context.insert(alexAct)
        
        try? context.save()
    }
}

