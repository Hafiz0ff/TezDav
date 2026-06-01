import Foundation
import SwiftData
@testable import TezDav

enum TestDataFactory {
    static let testBaseDate = Date(timeIntervalSince1970: 1767225600) // Jan 1, 2026 00:00:00 UTC

    static func makeUserSettings(
        appMode: AppMode = .pro,
        isMetric: Bool = true,
        maxHeartRate: Double = 190.0,
        restingHeartRate: Double = 60.0,
        cyclingFTP: Double = 250.0
    ) -> UserSettings {
        let settings = UserSettings()
        settings.appMode = appMode
        settings.isMetric = isMetric
        settings.maxHeartRate = maxHeartRate
        settings.restingHeartRate = restingHeartRate
        settings.cyclingFTP = cyclingFTP
        return settings
    }
    
    static func makeActivity(
        stravaId: Int64 = Int64.random(in: 100000...999999),
        sportType: String = "Run",
        name: String = "Morning Run",
        startDate: Date = testBaseDate,
        distanceMeters: Double = 5000.0,
        movingTime: TimeInterval = 1800.0,
        elapsedTime: TimeInterval = 1800.0,
        elevationGain: Double = 50.0,
        averageHeartRate: Double? = 150.0,
        averagePower: Double? = nil,
        averageCadence: Double? = 170.0,
        averageSpeed: Double? = 2.78,
        trimp: Double = 50.0,
        trainingLoad: Double = 50.0
    ) -> Activity {
        return Activity(
            stravaId: stravaId,
            sportType: sportType,
            name: name,
            startDate: startDate,
            distanceMeters: distanceMeters,
            movingTime: movingTime,
            elapsedTime: elapsedTime,
            elevationGain: elevationGain,
            averageHeartRate: averageHeartRate,
            averagePower: averagePower,
            averageCadence: averageCadence,
            averageSpeed: averageSpeed,
            encodedPolyline: nil,
            trimp: trimp,
            trainingLoad: trainingLoad,
            importedAt: testBaseDate,
            streamsImported: true,
            source: "strava"
        )
    }
    
    static func makeStreamSamples(activityId: Int64, count: Int = 10) -> [ActivityStreamSample] {
        var samples: [ActivityStreamSample] = []
        for i in 0..<count {
            let sample = ActivityStreamSample(
                activityId: activityId,
                offsetSeconds: i * 10,
                distanceMeters: Double(i * 10) * 2.78,
                latitude: 45.0 + Double(i) * 0.0001,
                longitude: 74.0 + Double(i) * 0.0001,
                heartRate: 140.0 + Double(i % 5) * 2.0,
                cadence: 168.0 + Double(i % 3) * 2.0,
                power: 200.0 + Double(i % 4) * 10.0,
                speed: 2.78,
                altitude: 100.0 + Double(i) * 0.5
            )
            samples.append(sample)
        }
        return samples
    }
    
    static func makeGearItem(
        name: String = "Pegasus 40",
        sportType: String = "Run",
        gearType: String = "shoes",
        brand: String? = "Nike",
        maxDistanceKm: Double = 700.0,
        currentDistanceKm: Double = 0.0,
        isActive: Bool = true,
        stravaGearId: String? = nil
    ) -> GearItem {
        return GearItem(
            name: name,
            sportType: sportType,
            gearType: gearType,
            brand: brand,
            startDate: testBaseDate.addingTimeInterval(-86400 * 30),
            maxDistanceKm: maxDistanceKm,
            currentDistanceKm: currentDistanceKm,
            isActive: isActive,
            stravaGearId: stravaGearId
        )
    }
    
    static func makeWeatherSnapshot(
        temperature: Double = 15.0,
        humidity: Double = 60.0,
        windSpeed: Double = 3.0,
        condition: String = "Clear",
        latitude: Double = 45.0,
        longitude: Double = 74.0,
        date: Date = testBaseDate
    ) -> WeatherSnapshot {
        return WeatherSnapshot(
            temperature: temperature,
            humidity: humidity,
            windSpeed: windSpeed,
            condition: condition,
            latitude: latitude,
            longitude: longitude,
            date: date
        )
    }
}
