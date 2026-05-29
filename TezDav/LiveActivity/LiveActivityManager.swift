import ActivityKit
import Foundation

/// Manages the lifecycle of workout Live Activities on the Lock Screen and Dynamic Island.
/// Call `startWorkout` when a workout session begins, `updateMetrics` every ~3 seconds,
/// and `endWorkout` when the session completes.
///
/// Note: Uses `ActivityKit.Activity` explicitly to avoid collision with the SwiftData `Activity` model.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: ActivityKit.Activity<WorkoutActivityAttributes>?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Whether Live Activities are available and enabled by the user.
    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    /// Whether a workout Live Activity is currently running.
    var isActive: Bool {
        currentActivity != nil
    }
    
    /// Starts a new Live Activity for the given sport type.
    /// - Parameter sportType: The Strava sport type string (e.g., "Run", "Ride").
    func startWorkout(sportType: String) {
        // End any existing activity first
        if currentActivity != nil {
            endWorkoutImmediately()
        }
        
        guard isAvailable else {
            print("[LiveActivity] Activities not enabled by user.")
            return
        }
        
        let attributes = WorkoutActivityAttributes(
            sportType: sportType,
            startTime: .now,
            sportIcon: WorkoutActivityAttributes.iconName(for: sportType)
        )
        
        let initialState = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: 0,
            distanceMeters: 0,
            currentPace: nil,
            currentSpeed: nil,
            heartRate: nil,
            calories: nil,
            cadence: nil,
            elevationGain: nil
        )
        
        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            currentActivity = try ActivityKit.Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("[LiveActivity] Started for \(sportType): \(currentActivity?.id ?? "nil")")
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }
    
    /// Updates the current Live Activity with new workout metrics.
    /// Should be called every ~3 seconds from WatchConnectivityManager.
    func updateMetrics(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity = currentActivity else {
            print("[LiveActivity] No active activity to update.")
            return
        }
        
        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
    }
    
    /// Ends the Live Activity with final metrics, keeping it visible for 5 minutes.
    func endWorkout(finalState: WorkoutActivityAttributes.ContentState) {
        guard let activity = currentActivity else { return }
        
        Task {
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .after(.now + 300))
            currentActivity = nil
            print("[LiveActivity] Ended with dismissal in 5 minutes.")
        }
    }
    
    /// Ends the Live Activity immediately without delay.
    func endWorkoutImmediately() {
        guard let activity = currentActivity else { return }
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
            print("[LiveActivity] Ended immediately.")
        }
    }
    
    /// Ends all TezDav workout Live Activities (cleanup on app launch).
    func endAllActivities() {
        Task {
            for activity in ActivityKit.Activity<WorkoutActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            currentActivity = nil
        }
    }
}
