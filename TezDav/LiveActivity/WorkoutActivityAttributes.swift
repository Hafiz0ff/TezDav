import ActivityKit
import Foundation

/// Defines the data model for TezDav workout Live Activities.
/// Static properties are set once at workout start; ContentState updates dynamically.
struct WorkoutActivityAttributes: ActivityAttributes {
    // Static data — set once when the workout begins
    let sportType: String           // "Run", "Ride", "Swim", "Walk", etc.
    let startTime: Date             // Workout start timestamp
    let sportIcon: String           // SF Symbol name: "figure.run", "bicycle", etc.

    /// Dynamic state updated every ~3 seconds during the workout.
    struct ContentState: Codable, Hashable {
        let elapsedSeconds: Int         // Total elapsed workout time
        let distanceMeters: Double      // Total distance covered
        let currentPace: Double?        // Current pace in seconds per kilometer (running)
        let currentSpeed: Double?       // Current speed in km/h (cycling)
        let heartRate: Int?             // Current heart rate in BPM
        let calories: Int?              // Estimated calories burned
        let cadence: Int?               // Steps/min (run) or RPM (ride)
        let elevationGain: Double?      // Total elevation gain in meters
    }
}

// MARK: - Sport Type Mapping Helpers

extension WorkoutActivityAttributes {
    /// Returns the appropriate SF Symbol for a given sport type string.
    static func iconName(for sportType: String) -> String {
        let lower = sportType.lowercased()
        if lower.contains("run") { return "figure.run" }
        if lower.contains("ride") || lower.contains("cycl") { return "bicycle" }
        if lower.contains("swim") { return "figure.pool.swim" }
        if lower.contains("walk") || lower.contains("hike") { return "figure.walk" }
        if lower.contains("ski") { return "figure.skiing.downhill" }
        return "figure.mixed.cardio"
    }
    
    /// Returns a localized display name for the sport type.
    static func displayName(for sportType: String) -> String {
        let lower = sportType.lowercased()
        if lower.contains("run") { return "Бег" }
        if lower.contains("ride") || lower.contains("cycl") { return "Велосипед" }
        if lower.contains("swim") { return "Плавание" }
        if lower.contains("walk") { return "Ходьба" }
        if lower.contains("hike") { return "Хайкинг" }
        if lower.contains("ski") { return "Лыжи" }
        return "Тренировка"
    }
    
    /// Whether pace (min/km) is the primary metric vs speed (km/h).
    static func usesPace(for sportType: String) -> Bool {
        let lower = sportType.lowercased()
        return lower.contains("run") || lower.contains("walk") || lower.contains("hike")
    }
}
