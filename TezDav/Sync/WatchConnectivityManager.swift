import ActivityKit
import Foundation
import WatchConnectivity

final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func start() {
        // Triggers initializer activation
        print("WatchConnectivity activated.")
    }
    
    // Sends the latest telemetry dashboard snapshot to Apple Watch
    func sendSnapshot(_ snapshot: DashboardSnapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        
        guard session.activationState == .activated else { return }
        
        if let data = try? JSONEncoder().encode(snapshot) {
            // Send via context update to ensure Watch always has the freshest snapshot on wake
            try? session.updateApplicationContext(["snapshot_data": data])
        }
    }
    
    // Sends a route to Apple Watch
    func sendRoute(name: String, distance: Double, elevation: Double, sportType: String, coordinatesData: Data) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        
        let message: [String: Any] = [
            "route_name": name,
            "route_distance": distance,
            "route_elevation": elevation,
            "route_sport": sportType,
            "route_coordinates": coordinatesData
        ]
        
        session.sendMessage(["route_data": message], replyHandler: nil, errorHandler: { error in
            print("Failed to send route to watch: \(error.localizedDescription)")
        })
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
        } else {
            print("WCSession activated successfully: \(activationState.rawValue)")
        }
    }
    
    /// Handles real-time messages from Apple Watch during active workouts.
    /// Three message types drive the Live Activity lifecycle:
    /// - "workout_started": Watch began a HKWorkoutSession → start Live Activity
    /// - "workout_live_data": Periodic metrics update (~every 3 sec) → update Live Activity
    /// - "workout_ended": Watch finished the workout → end Live Activity
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Workout started on Watch
        if let sportType = message["workout_started"] as? String {
            Task { @MainActor in
                LiveActivityManager.shared.startWorkout(sportType: sportType)
                print("[WatchConn] Workout started: \(sportType)")
            }
            return
        }
        
        // Live workout data update from Watch
        if let data = message["workout_live_data"] as? Data {
            if let state = try? JSONDecoder().decode(WorkoutActivityAttributes.ContentState.self, from: data) {
                Task { @MainActor in
                    LiveActivityManager.shared.updateMetrics(state)
                }
            }
            return
        }
        
        // Workout ended on Watch
        if let data = message["workout_ended"] as? Data {
            if let finalState = try? JSONDecoder().decode(WorkoutActivityAttributes.ContentState.self, from: data) {
                Task { @MainActor in
                    LiveActivityManager.shared.endWorkout(finalState: finalState)
                    print("[WatchConn] Workout ended.")
                }
            }
            return
        }
    }
    
    /// Handles real-time messages that expect a reply from Watch.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Delegate to the non-reply version and acknowledge
        self.session(session, didReceiveMessage: message)
        replyHandler(["status": "ok"])
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Required iOS delegate method
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Required iOS delegate method - reactivation helper
        WCSession.default.activate()
    }
    #endif
}
