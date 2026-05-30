import Foundation
import SwiftData
import CoreLocation

/// Simulates a live workout session for testing Live Activity and Live Segments without Apple Watch.
@MainActor
final class WorkoutSimulator: ObservableObject {
    static let shared = WorkoutSimulator()
    
    @Published var isSimulating = false
    @Published var elapsed = 0
    @Published var distance: Double = 0.0
    @Published var currentLatitude: Double = 38.5739
    @Published var currentLongitude: Double = 68.7979
    @Published var selectedSegment: Segment? = nil
    
    private var timer: Timer?
    private var coordinatePath: [CLLocationCoordinate2D] = []
    private var currentPathIndex = 0
    private var sportType = "Run"
    
    private init() {}
    
    /// Start simulating a workout of the given sport type, optionally traversing a segment.
    func start(
        sportType: String = "Run",
        segment: Segment? = nil,
        speedMultiplier: Int = 1,
        context: ModelContext
    ) {
        guard !isSimulating else { return }
        
        isSimulating = true
        self.sportType = sportType
        self.selectedSegment = segment
        self.elapsed = 0
        self.distance = 0.0
        self.currentPathIndex = 0
        
        // Reset the segment coordinator state
        LiveSegmentCoordinator.shared.reset()
        
        // Construct GPS coordinate path
        if let segment = segment {
            let coords = segment.coordinates
            if coords.count >= 2 {
                let c0 = coords[0]
                let c1 = coords[1]
                let dLat = c0.latitude - c1.latitude
                let dLon = c0.longitude - c1.longitude
                
                // 3 points before the segment start (extrapolated)
                let pre3 = CLLocationCoordinate2D(latitude: c0.latitude + dLat * 0.9, longitude: c0.longitude + dLon * 0.9)
                let pre2 = CLLocationCoordinate2D(latitude: c0.latitude + dLat * 0.6, longitude: c0.longitude + dLon * 0.6)
                let pre1 = CLLocationCoordinate2D(latitude: c0.latitude + dLat * 0.3, longitude: c0.longitude + dLon * 0.3)
                
                let last = coords[coords.count - 1]
                let secondLast = coords[coords.count - 2]
                let dLatLast = last.latitude - secondLast.latitude
                let dLonLast = last.longitude - secondLast.longitude
                
                // 3 points after the segment end (extrapolated)
                let post1 = CLLocationCoordinate2D(latitude: last.latitude + dLatLast * 0.3, longitude: last.longitude + dLonLast * 0.3)
                let post2 = CLLocationCoordinate2D(latitude: last.latitude + dLatLast * 0.6, longitude: last.longitude + dLonLast * 0.6)
                let post3 = CLLocationCoordinate2D(latitude: last.latitude + dLatLast * 0.9, longitude: last.longitude + dLonLast * 0.9)
                
                self.coordinatePath = [pre3, pre2, pre1] + coords + [post1, post2, post3]
            } else {
                self.coordinatePath = coords
            }
        } else {
            // Default path (simulate a small straight line run near Dushanbe center)
            var coords: [CLLocationCoordinate2D] = []
            let startLat = 38.5739
            let startLon = 68.7979
            for i in 0..<20 {
                coords.append(CLLocationCoordinate2D(latitude: startLat + Double(i) * 0.0001, longitude: startLon))
            }
            self.coordinatePath = coords
        }
        
        // Initialize coordinates to first path entry
        if let first = coordinatePath.first {
            self.currentLatitude = first.latitude
            self.currentLongitude = first.longitude
        }
        
        // Start Live Activity
        LiveActivityManager.shared.startWorkout(sportType: sportType)
        
        let isRun = sportType.lowercased().contains("run")
        let interval = 3.0 / Double(max(1, speedMultiplier))
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.elapsed += 3
                
                // Advance coordinate path index
                if self.currentPathIndex < self.coordinatePath.count - 1 {
                    self.currentPathIndex += 1
                    let prevCoord = self.coordinatePath[self.currentPathIndex - 1]
                    let currCoord = self.coordinatePath[self.currentPathIndex]
                    
                    self.currentLatitude = currCoord.latitude
                    self.currentLongitude = currCoord.longitude
                    
                    // Increment distance using Haversine formulas
                    let stepDist = SegmentMatcher.haversineDistance(
                        lat1: prevCoord.latitude, lon1: prevCoord.longitude,
                        lat2: currCoord.latitude, lon2: currCoord.longitude
                    )
                    self.distance += stepDist
                } else {
                    // Path finished, stop simulation
                    self.stop()
                    return
                }
                
                // Update coordinator
                LiveSegmentCoordinator.shared.updateLocation(
                    latitude: self.currentLatitude,
                    longitude: self.currentLongitude,
                    workoutDistance: self.distance,
                    elapsedSeconds: self.elapsed,
                    sportType: self.sportType,
                    context: context
                )
                
                // Package and send telemetry updates to Live Activity
                let coord = LiveSegmentCoordinator.shared
                let state = WorkoutActivityAttributes.ContentState(
                    elapsedSeconds: self.elapsed,
                    distanceMeters: self.distance,
                    currentPace: isRun ? Double.random(in: 250...320) : nil,
                    currentSpeed: isRun ? nil : Double.random(in: 25...35),
                    heartRate: Int.random(in: 135...172),
                    calories: Int(Double(self.elapsed) * 0.18),
                    cadence: isRun ? Int.random(in: 170...186) : Int.random(in: 80...95),
                    elevationGain: Double(self.elapsed) * 0.05,
                    currentLatitude: self.currentLatitude,
                    currentLongitude: self.currentLongitude,
                    segmentName: coord.activeSegment?.name,
                    segmentTimeAheadBehind: coord.isInsideSegment ? coord.timeAheadBehind : nil,
                    segmentDistanceRemaining: coord.isInsideSegment ? coord.distanceRemaining : nil,
                    segmentDistanceCovered: coord.isInsideSegment ? coord.distanceCovered : nil,
                    isInsideSegment: coord.isInsideSegment
                )
                
                LiveActivityManager.shared.updateMetrics(state)
            }
        }
    }
    
    /// Stop the simulation and end the Live Activity.
    func stop() {
        timer?.invalidate()
        timer = nil
        
        guard isSimulating else { return }
        isSimulating = false
        
        let finalState = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: elapsed,
            distanceMeters: distance,
            currentPace: nil,
            currentSpeed: nil,
            heartRate: nil,
            calories: Int(Double(elapsed) * 0.18),
            cadence: nil,
            elevationGain: Double(elapsed) * 0.05,
            currentLatitude: nil,
            currentLongitude: nil,
            segmentName: nil,
            segmentTimeAheadBehind: nil,
            segmentDistanceRemaining: nil,
            segmentDistanceCovered: nil,
            isInsideSegment: false
        )
        
        LiveActivityManager.shared.endWorkout(finalState: finalState)
        LiveSegmentCoordinator.shared.reset()
    }
}
