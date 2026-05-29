import Foundation

/// Simulates a live workout session for testing Live Activity without Apple Watch.
/// Only available in DEBUG builds. Generates realistic-looking workout data.
#if DEBUG
@MainActor
final class WorkoutSimulator {
    static let shared = WorkoutSimulator()
    
    private var timer: Timer?
    private var elapsed: Int = 0
    private var distance: Double = 0
    private var isRunning = false
    
    private init() {}
    
    /// Whether a simulation is currently active.
    var isSimulating: Bool { isRunning }
    
    /// Start simulating a workout of the given sport type.
    /// Updates Live Activity every 3 seconds with progressively increasing metrics.
    func start(sportType: String = "Run") {
        guard !isRunning else { return }
        isRunning = true
        elapsed = 0
        distance = 0
        
        // Start the Live Activity
        LiveActivityManager.shared.startWorkout(sportType: sportType)
        
        let isRun = sportType.lowercased().contains("run")
        
        // Timer fires every 3 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            
            Task { @MainActor in
                self.elapsed += 3
                
                // Simulate distance progression
                if isRun {
                    // ~4:30/km pace → ~3.7 m/s → ~11.1 m per 3 sec
                    self.distance += Double.random(in: 9.0...13.0)
                } else {
                    // ~30 km/h → ~8.3 m/s → ~25 m per 3 sec
                    self.distance += Double.random(in: 20.0...30.0)
                }
                
                let state = WorkoutActivityAttributes.ContentState(
                    elapsedSeconds: self.elapsed,
                    distanceMeters: self.distance,
                    currentPace: isRun ? Double.random(in: 250...320) : nil,
                    currentSpeed: isRun ? nil : Double.random(in: 25...35),
                    heartRate: Int.random(in: 135...172),
                    calories: Int(Double(self.elapsed) * 0.18),
                    cadence: isRun ? Int.random(in: 170...186) : Int.random(in: 80...95),
                    elevationGain: Double(self.elapsed) * 0.05
                )
                
                LiveActivityManager.shared.updateMetrics(state)
                
                // Auto-stop after 2 minutes of simulation
                if self.elapsed >= 120 {
                    self.stop()
                }
            }
        }
    }
    
    /// Stop the simulation and end the Live Activity.
    func stop() {
        timer?.invalidate()
        timer = nil
        
        guard isRunning else { return }
        isRunning = false
        
        let finalState = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: elapsed,
            distanceMeters: distance,
            currentPace: nil,
            currentSpeed: nil,
            heartRate: nil,
            calories: Int(Double(elapsed) * 0.18),
            cadence: nil,
            elevationGain: Double(elapsed) * 0.05
        )
        
        LiveActivityManager.shared.endWorkout(finalState: finalState)
    }
}
#endif
