import Foundation
import SwiftData

@Model
final class UserSettings {
    @Attribute(.unique) var key: String
    var maxHeartRate: Double
    var restingHeartRate: Double
    var runningThresholdPaceSecondsPerKm: Double
    var targetWeeklyDistanceMeters: Double

    // Personal details
    var birthDate: Date?
    var weightKg: Double
    var mainSport: String // "Run", "Ride", "Triathlon"

    // Heart rate zones details
    var isHeartRateZonesAutomatic: Bool
    var hrZone1Max: Double
    var hrZone2Max: Double
    var hrZone3Max: Double
    var hrZone4Max: Double

    // Thresholds
    var lthrPaceSecondsPerKm: Double
    var runningFTP: Double
    var cyclingFTP: Double
    var bikeWeightKg: Double?

    // Goals
    var weeklyCyclingGoalHours: Double
    var raceDate: Date?
    var raceDistanceMeters: Double?

    // Strava syncing details
    var stravaAccountName: String?
    var lastSyncedAt: Date?

    // Notifications state
    var lastTsbNotificationDate: Date?
    
    var isMetric: Bool = true

    init(
        key: String = "default",
        maxHeartRate: Double = 190,
        restingHeartRate: Double = 60,
        runningThresholdPaceSecondsPerKm: Double = 270,
        targetWeeklyDistanceMeters: Double = 50_000,
        birthDate: Date? = nil,
        weightKg: Double = 70.0,
        mainSport: String = "Run",
        isHeartRateZonesAutomatic: Bool = true,
        hrZone1Max: Double = 120,
        hrZone2Max: Double = 140,
        hrZone3Max: Double = 160,
        hrZone4Max: Double = 180,
        lthrPaceSecondsPerKm: Double = 270,
        runningFTP: Double = 250,
        cyclingFTP: Double = 250,
        bikeWeightKg: Double? = nil,
        weeklyCyclingGoalHours: Double = 5.0,
        raceDate: Date? = nil,
        raceDistanceMeters: Double? = nil,
        stravaAccountName: String? = nil,
        lastSyncedAt: Date? = nil,
        lastTsbNotificationDate: Date? = nil,
        isMetric: Bool = true
    ) {
        self.key = key
        self.maxHeartRate = maxHeartRate
        self.restingHeartRate = restingHeartRate
        self.runningThresholdPaceSecondsPerKm = runningThresholdPaceSecondsPerKm
        self.targetWeeklyDistanceMeters = targetWeeklyDistanceMeters
        self.birthDate = birthDate
        self.weightKg = weightKg
        self.mainSport = mainSport
        self.isHeartRateZonesAutomatic = isHeartRateZonesAutomatic
        self.hrZone1Max = hrZone1Max
        self.hrZone2Max = hrZone2Max
        self.hrZone3Max = hrZone3Max
        self.hrZone4Max = hrZone4Max
        self.lthrPaceSecondsPerKm = lthrPaceSecondsPerKm
        self.runningFTP = runningFTP
        self.cyclingFTP = cyclingFTP
        self.bikeWeightKg = bikeWeightKg
        self.weeklyCyclingGoalHours = weeklyCyclingGoalHours
        self.raceDate = raceDate
        self.raceDistanceMeters = raceDistanceMeters
        self.stravaAccountName = stravaAccountName
        self.lastSyncedAt = lastSyncedAt
        self.lastTsbNotificationDate = lastTsbNotificationDate
        self.isMetric = isMetric
    }

    // Dynamic Max HR Calculation: Max HR = 220 - Age (if not explicitly specified)
    var effectiveMaxHeartRate: Double {
        if maxHeartRate > 0 {
            return maxHeartRate
        }
        if let birthDate = birthDate {
            let calendar = Calendar.current
            let ageComponents = calendar.dateComponents([.year], from: birthDate, to: .now)
            if let age = ageComponents.year {
                return Double(220 - age)
            }
        }
        return 190.0
    }

    // Dynamic zone boundary array
    func effectiveHeartRateZones(maxHR: Double) -> [Double] {
        if isHeartRateZonesAutomatic {
            // Friel zones as standard percentages of Max HR
            return [
                maxHR * 0.65, // Zone 1 Max
                maxHR * 0.75, // Zone 2 Max
                maxHR * 0.85, // Zone 3 Max
                maxHR * 0.92  // Zone 4 Max
            ]
        } else {
            return [
                hrZone1Max,
                hrZone2Max,
                hrZone3Max,
                hrZone4Max
            ]
        }
    }

    // Helper to get or insert the default settings model
    static func getOrCreate(in context: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let newSettings = UserSettings()
        context.insert(newSettings)
        try? context.save()
        return newSettings
    }
}

