// swiftlint:disable cyclomatic_complexity
import CoreLocation
import Foundation
import HealthKit
import SwiftData

@MainActor
final class HealthKitWorkoutImporter {
    struct ImportReport: Equatable, Sendable {
        var imported = 0
        var updated = 0
        var skipped = 0
        var failed = 0

        var saved: Int { imported + updated }
    }

    enum ImportError: LocalizedError {
        case healthDataUnavailable

        var errorDescription: String? {
            switch self {
            case .healthDataUnavailable:
                return "Данные Apple Health недоступны на этом устройстве."
            }
        }
    }

    static let shared = HealthKitWorkoutImporter()

    private let healthStore: HKHealthStore?

    private init() {
        healthStore = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    func importAll(into context: ModelContext, progress: SyncProgress) async -> ImportReport {
        guard healthStore != nil else {
            progress.phase = .failed(ImportError.healthDataUnavailable.localizedDescription)
            return ImportReport(failed: 1)
        }

        progress.phase = .authenticating

        do {
            let workouts = try await fetchWorkouts()
            var report = ImportReport()
            var activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
            var activitiesByHealthKitID: [String: Activity] = [:]
            for activity in activities {
                guard let healthKitID = activity.healthKitUUID else { continue }
                activitiesByHealthKitID[healthKitID] = activitiesByHealthKitID[healthKitID] ?? activity
            }
            var occupiedIDs = Set(activities.map(\.stravaId))
            let settings = UserSettings.getOrCreate(in: context)

            for (index, workout) in workouts.enumerated() {
                progress.phase = .importing(page: index + 1, imported: report.saved)
                let healthKitID = workout.uuid.uuidString

                if isWorkoutCreatedByTezDav(workout) {
                    report.skipped += 1
                    continue
                }

                if let existing = activitiesByHealthKitID[healthKitID] {
                    if existing.source != "healthkit" || !shouldRefresh(existing, workout: workout) {
                        report.skipped += 1
                        continue
                    }

                    do {
                        let payload = try await makePayload(for: workout, activityID: existing.stravaId)
                        replaceStreams(for: existing.stravaId, with: payload.samples, context: context)
                        apply(payload, healthKitID: healthKitID, to: existing, settings: settings)
                        enrich(existing, samples: payload.samples, context: context)
                        report.updated += 1
                    } catch {
                        report.failed += 1
                    }
                    continue
                }

                if let duplicate = activities.first(where: {
                    Self.isProbableDuplicate(
                        existingStartDate: $0.startDate,
                        existingDistanceMeters: $0.distanceMeters,
                        candidateStartDate: workout.startDate,
                        candidateDistanceMeters: workoutDistance(workout)
                    )
                }) {
                    duplicate.healthKitUUID = healthKitID
                    activitiesByHealthKitID[healthKitID] = duplicate
                    report.skipped += 1
                    continue
                }

                let activityID = availableActivityID(for: workout.uuid, occupiedIDs: &occupiedIDs)
                do {
                    let payload = try await makePayload(for: workout, activityID: activityID)
                    let activity = makeActivity(
                        from: payload,
                        healthKitID: healthKitID,
                        settings: settings
                    )
                    context.insert(activity)
                    for sample in payload.samples {
                        context.insert(sample)
                    }
                    enrich(activity, samples: payload.samples, context: context)
                    activities.append(activity)
                    activitiesByHealthKitID[healthKitID] = activity
                    report.imported += 1
                } catch {
                    report.failed += 1
                }

                if index.isMultiple(of: 20) {
                    try context.save()
                }
            }

            TrainingLoadCalculator.recalculateAllActivities(context: context, settings: settings)
            updateSyncState(
                in: context,
                totalImported: activitiesByHealthKitID.count,
                newestWorkoutDate: workouts.map(\.startDate).max(),
                failedCount: report.failed
            )
            try context.save()
            progress.phase = .finished(imported: report.saved)
            return report
        } catch {
            updateSyncState(
                in: context,
                totalImported: 0,
                newestWorkoutDate: nil,
                errorMessage: error.localizedDescription
            )
            try? context.save()
            progress.phase = .failed(error.localizedDescription)
            return ImportReport(failed: 1)
        }
    }

    nonisolated static func stableActivityID(for uuid: UUID) -> Int64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in uuid.uuidString.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let namespaced = UInt64(0x6000_0000_0000_0000) | (hash & 0x0FFF_FFFF_FFFF_FFFF)
        return Int64(bitPattern: namespaced)
    }

    nonisolated static func isProbableDuplicate(
        existingStartDate: Date,
        existingDistanceMeters: Double,
        candidateStartDate: Date,
        candidateDistanceMeters: Double
    ) -> Bool {
        let startDifference = abs(existingStartDate.timeIntervalSince(candidateStartDate))
        let distanceDifference = abs(existingDistanceMeters - candidateDistanceMeters)
        return startDifference <= 5 && distanceDifference <= 30
    }

    nonisolated static func sportType(for workoutType: HKWorkoutActivityType) -> String {
        switch workoutType {
        case .running:
            return "Run"
        case .cycling:
            return "Ride"
        case .walking:
            return "Walk"
        case .hiking:
            return "Hike"
        case .swimming:
            return "Swim"
        case .rowing:
            return "Rowing"
        case .elliptical:
            return "Elliptical"
        case .stairClimbing:
            return "StairClimbing"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return "StrengthTraining"
        case .yoga:
            return "Yoga"
        case .pilates:
            return "Pilates"
        case .crossTraining:
            return "CrossTraining"
        case .coreTraining:
            return "CoreTraining"
        case .flexibility:
            return "Flexibility"
        default:
            return "Workout"
        }
    }

    private struct WorkoutPayload {
        let activityID: Int64
        let sportType: String
        let name: String
        let startDate: Date
        let distanceMeters: Double
        let movingTime: TimeInterval
        let elapsedTime: TimeInterval
        let elevationGain: Double
        let elevationLoss: Double
        let maxAltitude: Double?
        let averageHeartRate: Double?
        let averagePower: Double?
        let averageCadence: Double?
        let averageSpeed: Double?
        let stepsCount: Int?
        let swimStrokeCount: Int?
        let samples: [ActivityStreamSample]
    }

    private struct StreamPoint {
        var distanceMeters: Double?
        var latitude: Double?
        var longitude: Double?
        var heartRate: Double?
        var cadence: Double?
        var power: Double?
        var speed: Double?
        var altitude: Double?
        var verticalOscillation: Double?
        var groundContactTime: Double?
        var strideLength: Double?
    }

    private func fetchWorkouts() async throws -> [HKWorkout] {
        guard let healthStore else { throw ImportError.healthDataUnavailable }

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: nil,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(
                        key: HKSampleSortIdentifierStartDate,
                        ascending: true
                    )
                ]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func makePayload(for workout: HKWorkout, activityID: Int64) async throws -> WorkoutPayload {
        let sportType = Self.sportType(for: workout.workoutActivityType)
        let distanceType = distanceType(for: workout.workoutActivityType)
        let speedType = speedType(for: workout.workoutActivityType)
        let powerType = powerType(for: workout.workoutActivityType)
        let cadenceType = cadenceType(for: workout.workoutActivityType)

        // Route access can be denied independently from workout access. Keep the
        // workout and its metrics importable even when no route can be read.
        let routeLocations = (try? await fetchRouteLocations(for: workout)) ?? []
        let heartRates = await quantitySamples(for: workout, type: quantityType(.heartRate))
        let distances = await quantitySamples(for: workout, type: distanceType)
        let speeds = await quantitySamples(for: workout, type: speedType)
        let powers = await quantitySamples(for: workout, type: powerType)
        let cadences = await quantitySamples(for: workout, type: cadenceType)
        let steps = await quantitySamples(for: workout, type: stepType(for: workout.workoutActivityType))
        let strokes = await quantitySamples(for: workout, type: strokeType(for: workout.workoutActivityType))
        let verticalOscillation = await quantitySamples(
            for: workout,
            type: workout.workoutActivityType == .running ? quantityType(.runningVerticalOscillation) : nil
        )
        let groundContactTime = await quantitySamples(
            for: workout,
            type: workout.workoutActivityType == .running ? quantityType(.runningGroundContactTime) : nil
        )
        let strideLength = await quantitySamples(
            for: workout,
            type: workout.workoutActivityType == .running ? quantityType(.runningStrideLength) : nil
        )

        var streamPoints: [Int: StreamPoint] = [:]
        var routeDistance = 0.0
        var previousLocation: CLLocation?
        var elevationGain = 0.0
        var elevationLoss = 0.0
        var maxAltitude: Double?

        for location in routeLocations.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard location.horizontalAccuracy >= 0 else { continue }
            let offset = sampleOffset(location.timestamp, workout: workout)
            if let previousLocation {
                routeDistance += max(0, location.distance(from: previousLocation))
                if location.verticalAccuracy >= 0 && previousLocation.verticalAccuracy >= 0 {
                    let delta = location.altitude - previousLocation.altitude
                    if delta > 1 {
                        elevationGain += delta
                    } else if delta < -1 {
                        elevationLoss += abs(delta)
                    }
                }
            }

            var point = streamPoints[offset] ?? StreamPoint()
            point.latitude = location.coordinate.latitude
            point.longitude = location.coordinate.longitude
            point.distanceMeters = routeDistance
            if location.verticalAccuracy >= 0 {
                point.altitude = location.altitude
                maxAltitude = max(maxAltitude ?? location.altitude, location.altitude)
            }
            if location.speed >= 0 {
                point.speed = location.speed
            }
            streamPoints[offset] = point
            previousLocation = location
        }

        merge(heartRates, unit: .count().unitDivided(by: .minute()), workout: workout, into: &streamPoints) {
            $0.heartRate = $1
        }
        merge(speeds, unit: .meter().unitDivided(by: .second()), workout: workout, into: &streamPoints) {
            $0.speed = $1
        }
        merge(powers, unit: .watt(), workout: workout, into: &streamPoints) {
            $0.power = $1
        }
        merge(cadences, unit: .count().unitDivided(by: .minute()), workout: workout, into: &streamPoints) {
            $0.cadence = $1
        }
        merge(verticalOscillation, unit: .meter(), workout: workout, into: &streamPoints) {
            $0.verticalOscillation = $1 * 100
        }
        merge(groundContactTime, unit: .secondUnit(with: .milli), workout: workout, into: &streamPoints) {
            $0.groundContactTime = $1
        }
        merge(strideLength, unit: .meter(), workout: workout, into: &streamPoints) {
            $0.strideLength = $1
        }

        var cumulativeDistance = 0.0
        for sample in distances.sorted(by: { $0.endDate < $1.endDate }) {
            cumulativeDistance += max(0, sample.quantity.doubleValue(for: .meter()))
            let offset = sampleOffset(sample.endDate, workout: workout)
            var point = streamPoints[offset] ?? StreamPoint()
            point.distanceMeters = cumulativeDistance
            streamPoints[offset] = point
        }

        if cadenceType == nil {
            for sample in steps {
                let durationMinutes = sample.endDate.timeIntervalSince(sample.startDate) / 60
                guard durationMinutes > 0 else { continue }
                let cadence = sample.quantity.doubleValue(for: .count()) / durationMinutes
                let offset = sampleOffset(sample.endDate, workout: workout)
                var point = streamPoints[offset] ?? StreamPoint()
                point.cadence = cadence
                streamPoints[offset] = point
            }
        }

        let samples = streamPoints.keys.sorted().map { offset in
            let point = streamPoints[offset] ?? StreamPoint()
            return ActivityStreamSample(
                activityId: activityID,
                offsetSeconds: offset,
                distanceMeters: point.distanceMeters,
                latitude: point.latitude,
                longitude: point.longitude,
                heartRate: point.heartRate,
                cadence: point.cadence,
                power: point.power,
                speed: point.speed,
                altitude: point.altitude,
                verticalOscillation: point.verticalOscillation,
                groundContactTime: point.groundContactTime,
                strideLength: point.strideLength
            )
        }

        let elapsedTime = max(0, workout.endDate.timeIntervalSince(workout.startDate))
        let distance = max(
            workoutDistance(workout),
            cumulativeDistance,
            routeDistance
        )
        let averageHeartRate = averageQuantity(
            workout,
            type: quantityType(.heartRate),
            unit: .count().unitDivided(by: .minute())
        ) ?? average(samples.compactMap(\.heartRate))
        let averagePower = averageQuantity(workout, type: powerType, unit: .watt())
            ?? average(samples.compactMap(\.power))
        let averageCadence = averageQuantity(
            workout,
            type: cadenceType,
            unit: .count().unitDivided(by: .minute())
        ) ?? average(samples.compactMap(\.cadence))
        let averageSpeed = averageQuantity(
            workout,
            type: speedType,
            unit: .meter().unitDivided(by: .second())
        ) ?? average(samples.compactMap(\.speed))
            ?? (workout.duration > 0 ? distance / workout.duration : nil)

        return WorkoutPayload(
            activityID: activityID,
            sportType: sportType,
            name: displayName(for: workout.workoutActivityType),
            startDate: workout.startDate,
            distanceMeters: distance,
            movingTime: workout.duration,
            elapsedTime: elapsedTime,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            maxAltitude: maxAltitude,
            averageHeartRate: averageHeartRate,
            averagePower: averagePower,
            averageCadence: averageCadence,
            averageSpeed: averageSpeed,
            stepsCount: summedCount(steps),
            swimStrokeCount: summedCount(strokes),
            samples: samples
        )
    }

    private func makeActivity(
        from payload: WorkoutPayload,
        healthKitID: String,
        settings: UserSettings
    ) -> Activity {
        let input = metricInput(for: payload)
        return Activity(
            stravaId: payload.activityID,
            sportType: payload.sportType,
            name: payload.name,
            startDate: payload.startDate,
            distanceMeters: payload.distanceMeters,
            movingTime: payload.movingTime,
            elapsedTime: payload.elapsedTime,
            elevationGain: payload.elevationGain,
            averageHeartRate: payload.averageHeartRate,
            averagePower: payload.averagePower,
            averageCadence: payload.averageCadence,
            averageSpeed: payload.averageSpeed,
            trimp: TrainingLoadCalculator.trimp(
                duration: payload.movingTime,
                averageHeartRate: payload.averageHeartRate,
                restingHeartRate: settings.restingHeartRate,
                maxHeartRate: settings.effectiveMaxHeartRate
            ),
            trainingLoad: TrainingLoadCalculator.activityLoad(
                input,
                maxHeartRate: settings.effectiveMaxHeartRate
            ),
            streamsImported: true,
            source: "healthkit",
            healthKitUUID: healthKitID,
            startLatitude: payload.samples.compactMap(\.latitude).first,
            startLongitude: payload.samples.compactMap(\.longitude).first,
            stepsCount: payload.stepsCount,
            activeMinutes: Int(payload.movingTime / 60),
            maxAltitude: payload.maxAltitude,
            totalElevationLoss: payload.elevationLoss,
            swimStrokeCount: payload.swimStrokeCount,
            pace100m: payload.sportType == "Swim" && payload.distanceMeters > 0
                ? payload.movingTime / (payload.distanceMeters / 100)
                : nil
        )
    }

    private func apply(
        _ payload: WorkoutPayload,
        healthKitID: String,
        to activity: Activity,
        settings: UserSettings
    ) {
        activity.sportType = payload.sportType
        activity.name = payload.name
        activity.startDate = payload.startDate
        activity.distanceMeters = payload.distanceMeters
        activity.movingTime = payload.movingTime
        activity.elapsedTime = payload.elapsedTime
        activity.elevationGain = payload.elevationGain
        activity.averageHeartRate = payload.averageHeartRate
        activity.averagePower = payload.averagePower
        activity.averageCadence = payload.averageCadence
        activity.averageSpeed = payload.averageSpeed
        activity.trimp = TrainingLoadCalculator.trimp(
            duration: payload.movingTime,
            averageHeartRate: payload.averageHeartRate,
            restingHeartRate: settings.restingHeartRate,
            maxHeartRate: settings.effectiveMaxHeartRate
        )
        activity.trainingLoad = TrainingLoadCalculator.activityLoad(
            metricInput(for: payload),
            maxHeartRate: settings.effectiveMaxHeartRate
        )
        activity.importedAt = .now
        activity.streamsImported = true
        activity.source = "healthkit"
        activity.healthKitUUID = healthKitID
        activity.startLatitude = payload.samples.compactMap(\.latitude).first
        activity.startLongitude = payload.samples.compactMap(\.longitude).first
        activity.stepsCount = payload.stepsCount
        activity.activeMinutes = Int(payload.movingTime / 60)
        activity.maxAltitude = payload.maxAltitude
        activity.totalElevationLoss = payload.elevationLoss
        activity.swimStrokeCount = payload.swimStrokeCount
        activity.pace100m = payload.sportType == "Swim" && payload.distanceMeters > 0
            ? payload.movingTime / (payload.distanceMeters / 100)
            : nil
    }

    private func enrich(
        _ activity: Activity,
        samples: [ActivityStreamSample],
        context: ModelContext
    ) {
        PersonalRecordCalculator.calculateAndSetRecords(for: activity, samples: samples)
        SegmentMatcher.matchSegments(for: activity, samples: samples, context: context)
        PersonalSegmentMatcher.matchPersonalSegments(for: activity, samples: samples, context: context)
        RouteMatcher.matchRoute(for: activity, samples: samples, context: context)
    }

    private func replaceStreams(
        for activityID: Int64,
        with samples: [ActivityStreamSample],
        context: ModelContext
    ) {
        let descriptor = FetchDescriptor<ActivityStreamSample>(
            predicate: #Predicate { $0.activityId == activityID }
        )
        if let existingSamples = try? context.fetch(descriptor) {
            for sample in existingSamples {
                context.delete(sample)
            }
        }
        for sample in samples {
            context.insert(sample)
        }
    }

    private func quantitySamples(
        for workout: HKWorkout,
        type: HKQuantityType?
    ) async -> [HKQuantitySample] {
        guard let healthStore, let type else { return [] }
        let predicate = HKQuery.predicateForObjects(from: workout)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                ]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchRouteLocations(for workout: HKWorkout) async throws -> [CLLocation] {
        guard let healthStore else { throw ImportError.healthDataUnavailable }
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            healthStore.execute(query)
        }

        var allLocations: [CLLocation] = []
        for route in routes {
            let locations = try await fetchLocations(for: route)
            allLocations.append(contentsOf: locations)
        }
        return allLocations
    }

    private func fetchLocations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
        guard let healthStore else { throw ImportError.healthDataUnavailable }

        return try await withCheckedThrowingContinuation { continuation in
            var collected: [CLLocation] = []
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                collected.append(contentsOf: locations ?? [])
                if done {
                    continuation.resume(returning: collected)
                }
            }
            healthStore.execute(query)
        }
    }

    private func merge(
        _ samples: [HKQuantitySample],
        unit: HKUnit,
        workout: HKWorkout,
        into points: inout [Int: StreamPoint],
        update: (inout StreamPoint, Double) -> Void
    ) {
        for sample in samples {
            let offset = sampleOffset(sample.startDate, workout: workout)
            var point = points[offset] ?? StreamPoint()
            update(&point, sample.quantity.doubleValue(for: unit))
            points[offset] = point
        }
    }

    private func averageQuantity(
        _ workout: HKWorkout,
        type: HKQuantityType?,
        unit: HKUnit
    ) -> Double? {
        guard let type else { return nil }
        return workout.statistics(for: type)?.averageQuantity()?.doubleValue(for: unit)
    }

    private func workoutDistance(_ workout: HKWorkout) -> Double {
        guard let type = distanceType(for: workout.workoutActivityType) else {
            return workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        }
        return workout.statistics(for: type)?.sumQuantity()?.doubleValue(for: .meter())
            ?? workout.totalDistance?.doubleValue(for: .meter())
            ?? 0
    }

    private func metricInput(for payload: WorkoutPayload) -> ActivityMetricInput {
        ActivityMetricInput(
            date: payload.startDate,
            duration: payload.movingTime,
            distanceMeters: payload.distanceMeters,
            averageHeartRate: payload.averageHeartRate,
            averagePower: payload.averagePower,
            sportType: payload.sportType
        )
    }

    private func updateSyncState(
        in context: ModelContext,
        totalImported: Int,
        newestWorkoutDate: Date?,
        failedCount: Int = 0,
        errorMessage: String? = nil
    ) {
        let descriptor = FetchDescriptor<SyncState>(
            predicate: #Predicate { $0.key == "healthkit" }
        )
        let state: SyncState
        if let existing = try? context.fetch(descriptor).first {
            state = existing
        } else {
            state = SyncState(key: "healthkit")
            context.insert(state)
        }

        state.lastSuccessfulSync = errorMessage == nil ? .now : state.lastSuccessfulSync
        state.lastActivityStartDate = newestWorkoutDate ?? state.lastActivityStartDate
        state.importedActivityCount = max(state.importedActivityCount, totalImported)
        state.lastErrorMessage = errorMessage ?? (failedCount > 0
            ? "Не удалось прочитать \(failedCount) тренировок."
            : nil)
    }

    private func availableActivityID(for uuid: UUID, occupiedIDs: inout Set<Int64>) -> Int64 {
        var candidate = Self.stableActivityID(for: uuid)
        while occupiedIDs.contains(candidate) {
            candidate += 1
        }
        occupiedIDs.insert(candidate)
        return candidate
    }

    private func shouldRefresh(_ activity: Activity, workout: HKWorkout) -> Bool {
        !activity.streamsImported || workout.endDate > Date().addingTimeInterval(-7 * 86_400)
    }

    private func isWorkoutCreatedByTezDav(_ workout: HKWorkout) -> Bool {
        let bundleIdentifier = workout.sourceRevision.source.bundleIdentifier
        let brandName = workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String
        return bundleIdentifier == Bundle.main.bundleIdentifier || brandName == "TezDav Sync"
    }

    private func sampleOffset(_ date: Date, workout: HKWorkout) -> Int {
        max(0, Int(date.timeIntervalSince(workout.startDate).rounded()))
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func summedCount(_ samples: [HKQuantitySample]) -> Int? {
        guard !samples.isEmpty else { return nil }
        return Int(samples.reduce(0) { result, sample in
            result + sample.quantity.doubleValue(for: .count())
        }.rounded())
    }

    private func quantityType(_ identifier: HKQuantityTypeIdentifier) -> HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: identifier)
    }

    private func distanceType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        switch activityType {
        case .cycling:
            return quantityType(.distanceCycling)
        case .swimming:
            return quantityType(.distanceSwimming)
        case .running, .walking, .hiking:
            return quantityType(.distanceWalkingRunning)
        default:
            return nil
        }
    }

    private func speedType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        switch activityType {
        case .cycling:
            return quantityType(.cyclingSpeed)
        case .running:
            return quantityType(.runningSpeed)
        default:
            return nil
        }
    }

    private func powerType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        switch activityType {
        case .cycling:
            return quantityType(.cyclingPower)
        case .running:
            return quantityType(.runningPower)
        default:
            return nil
        }
    }

    private func cadenceType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        activityType == .cycling ? quantityType(.cyclingCadence) : nil
    }

    private func stepType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        switch activityType {
        case .running, .walking, .hiking:
            return quantityType(.stepCount)
        default:
            return nil
        }
    }

    private func strokeType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        activityType == .swimming ? quantityType(.swimmingStrokeCount) : nil
    }

    private func displayName(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running:
            return "Бег"
        case .cycling:
            return "Велотренировка"
        case .walking:
            return "Ходьба"
        case .hiking:
            return "Поход"
        case .swimming:
            return "Плавание"
        case .rowing:
            return "Гребля"
        case .elliptical:
            return "Эллиптический тренажёр"
        case .stairClimbing:
            return "Лестница"
        case .highIntensityIntervalTraining:
            return "Интервальная тренировка"
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return "Силовая тренировка"
        case .yoga:
            return "Йога"
        case .pilates:
            return "Пилатес"
        default:
            return "Тренировка"
        }
    }
}
