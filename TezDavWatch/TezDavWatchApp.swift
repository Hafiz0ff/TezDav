import HealthKit
import SwiftUI
import WatchConnectivity

class WatchViewModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var snapshot = DashboardSnapshot(
        ctl: 45.2,
        atl: 58.4,
        tsb: -13.2,
        weeklyDistanceMeters: 32400.0,
        weeklyDuration: 9400.0,
        weeklyGoalMeters: 50000.0,
        weeklyCyclingGoalHours: 5.0,
        recoveryScore: 7,
        lastActivityName: "Вечерний бег",
        lastActivityDate: Date().addingTimeInterval(-86400),
        lastActivityDistance: 10200.0
    )
    
    // Workout state
    @Published var isWorkoutActive = false
    @Published var workoutElapsed: Int = 0
    @Published var workoutDistance: Double = 0
    @Published var workoutHeartRate: Int = 0
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var liveDataTimer: Timer?
    private var workoutStartDate: Date?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - Workout Control
    
    /// Starts a workout session and begins sending live data to iPhone.
    func startWorkout(sportType: String = "Run") {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let activityType: HKWorkoutActivityType = sportType.lowercased().contains("ride") ? .cycling : .running
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            
            workoutSession?.startActivity(with: .now)
            try workoutBuilder?.beginCollection(withStart: .now) { _, _ in }
            
            workoutStartDate = .now
            isWorkoutActive = true
            workoutElapsed = 0
            workoutDistance = 0
            workoutHeartRate = 0
            
            // Notify iPhone to start Live Activity
            sendToiPhone(["workout_started": sportType])
            
            // Start periodic live data sending (every 3 seconds)
            startLiveDataTimer(sportType: sportType)
            
        } catch {
            print("[Watch] Failed to start workout: \(error)")
        }
    }
    
    /// Stops the workout session and sends final data to iPhone.
    func stopWorkout() {
        guard isWorkoutActive else { return }
        
        liveDataTimer?.invalidate()
        liveDataTimer = nil
        
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: .now) { [weak self] _, _ in
            self?.workoutBuilder?.finishWorkout { _, _ in }
        }
        
        // Send final state to iPhone to end Live Activity
        let finalState = WorkoutLiveData(
            elapsedSeconds: workoutElapsed,
            distanceMeters: workoutDistance,
            currentPace: nil,
            currentSpeed: nil,
            heartRate: nil,
            calories: Int(Double(workoutElapsed) * 0.15),
            cadence: nil,
            elevationGain: nil
        )
        
        if let data = try? JSONEncoder().encode(finalState) {
            sendToiPhone(["workout_ended": data])
        }
        
        isWorkoutActive = false
    }
    
    // MARK: - Live Data Timer
    
    private func startLiveDataTimer(sportType: String) {
        let isRun = sportType.lowercased().contains("run")
        
        liveDataTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self, self.isWorkoutActive else { return }
            
            self.workoutElapsed += 3
            
            // Accumulate simulated distance (real HKWorkoutBuilder provides actual values)
            if isRun {
                self.workoutDistance += Double.random(in: 9.0...13.0)
            } else {
                self.workoutDistance += Double.random(in: 20.0...30.0)
            }
            
            // Simulated HR (real values come from HKLiveWorkoutBuilder queries)
            self.workoutHeartRate = Int.random(in: 135...172)
            
            let liveData = WorkoutLiveData(
                elapsedSeconds: self.workoutElapsed,
                distanceMeters: self.workoutDistance,
                currentPace: isRun ? Double.random(in: 250...320) : nil,
                currentSpeed: isRun ? nil : Double.random(in: 25...35),
                heartRate: self.workoutHeartRate,
                calories: Int(Double(self.workoutElapsed) * 0.15),
                cadence: isRun ? Int.random(in: 170...186) : Int.random(in: 80...95),
                elevationGain: Double(self.workoutElapsed) * 0.04
            )
            
            if let data = try? JSONEncoder().encode(liveData) {
                self.sendToiPhone(["workout_live_data": data])
            }
        }
    }
    
    // MARK: - WCSession Communication
    
    private func sendToiPhone(_ message: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            print("[Watch] iPhone not reachable, skipping message.")
            return
        }
        session.sendMessage(message, replyHandler: nil) { error in
            print("[Watch] Send error: \(error)")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch session activated state: \(activationState.rawValue)")
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let data = applicationContext["snapshot_data"] as? Data {
            if let decoded = try? JSONDecoder().decode(DashboardSnapshot.self, from: data) {
                DispatchQueue.main.async {
                    self.snapshot = decoded
                }
            }
        }
    }
}

/// Codable struct matching WorkoutActivityAttributes.ContentState for Watch→iPhone transfer.
/// Duplicated here because the Watch target cannot import ActivityKit.
struct WorkoutLiveData: Codable {
    let elapsedSeconds: Int
    let distanceMeters: Double
    let currentPace: Double?
    let currentSpeed: Double?
    let heartRate: Int?
    let calories: Int?
    let cadence: Int?
    let elevationGain: Double?
}

@main
struct TezDavWatchApp: App {
    @StateObject private var viewModel = WatchViewModel()
    
    var body: some Scene {
        WindowGroup {
            TezDavWatchView()
                .environmentObject(viewModel)
        }
    }
}

