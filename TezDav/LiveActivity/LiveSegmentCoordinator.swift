import Foundation
import SwiftData
import CoreLocation

@MainActor
final class LiveSegmentCoordinator: ObservableObject {
    static let shared = LiveSegmentCoordinator()
    
    @Published var activeSegment: Segment? = nil
    @Published var isInsideSegment: Bool = false
    @Published var distanceCovered: Double = 0
    @Published var distanceRemaining: Double = 0
    @Published var timeAheadBehind: Double = 0
    @Published var segmentProgress: Double = 0
    @Published var targetTime: Double = 0
    @Published var elapsedSegmentTime: Double = 0
    @Published var segmentCompleted: Bool = false
    
    // Internal state variables for start offsets
    private var distanceAtStart: Double = 0
    private var timeAtStart: Int = 0
    
    private init() {}
    
    /// Resets all tracking variables to standard state
    func reset() {
        activeSegment = nil
        isInsideSegment = false
        distanceCovered = 0
        distanceRemaining = 0
        timeAheadBehind = 0
        segmentProgress = 0
        targetTime = 0
        elapsedSegmentTime = 0
        segmentCompleted = false
    }
    
    /// Receives live GPS coordinate and telemetry updates, checks proximity to segments, snaps matching, and updates Live Activities.
    func updateLocation(
        latitude: Double,
        longitude: Double,
        workoutDistance: Double,
        elapsedSeconds: Int,
        sportType: String,
        context: ModelContext
    ) {
        // If segment completed screen is currently showing, skip updates until it resets
        guard !segmentCompleted else { return }
        
        let isCycling = sportType.lowercased().contains("ride")
        let isRunning = sportType.lowercased().contains("run")
        
        if !isInsideSegment {
            // Check proximity to all segments matching sportType
            let fetchDescriptor = FetchDescriptor<Segment>()
            guard let segments = try? context.fetch(fetchDescriptor) else { return }
            
            for segment in segments {
                let segmentIsRun = segment.sportType.lowercased().contains("run")
                let segmentIsRide = segment.sportType.lowercased().contains("ride")
                
                if (segmentIsRun && !isRunning) || (segmentIsRide && !isCycling) {
                    continue
                }
                
                let distToStart = SegmentMatcher.haversineDistance(
                    lat1: latitude, lon1: longitude,
                    lat2: segment.startLatitude, lon2: segment.startLongitude
                )
                
                // If within 25 meters, trigger start
                if distToStart <= 25.0 {
                    activeSegment = segment
                    isInsideSegment = true
                    distanceAtStart = workoutDistance
                    timeAtStart = elapsedSeconds
                    distanceCovered = 0
                    distanceRemaining = segment.distanceMeters
                    timeAheadBehind = 0
                    segmentProgress = 0
                    segmentCompleted = false
                    elapsedSegmentTime = 0
                    
                    let bestEffort = segment.efforts.min(by: { $0.elapsedTime < $1.elapsedTime })
                    targetTime = bestEffort?.elapsedTime ?? 300.0
                    
                    HapticManager.success()
                    print("[LiveSegment] Entered segment: \(segment.name)")
                    break
                }
            }
        } else if let segment = activeSegment {
            // Snapping logic to segment's coordinate path
            let coords = segment.coordinates
            guard !coords.isEmpty else { return }
            
            var minDistance = Double.greatestFiniteMagnitude
            var closestIdx = 0
            
            for (idx, coord) in coords.enumerated() {
                let d = SegmentMatcher.haversineDistance(
                    lat1: latitude, lon1: longitude,
                    lat2: coord.latitude, lon2: coord.longitude
                )
                if d < minDistance {
                    minDistance = d
                    closestIdx = idx
                }
            }
            
            // Calculate progress and metrics
            let progress = Double(closestIdx) / Double(coords.count - 1)
            segmentProgress = progress
            distanceCovered = segment.distanceMeters * progress
            distanceRemaining = max(0, segment.distanceMeters - distanceCovered)
            
            let actualTime = Double(elapsedSeconds - timeAtStart)
            elapsedSegmentTime = actualTime
            
            // Gap vs Leader (KOM/PR)
            let targetTimeAtPoint = targetTime * progress
            timeAheadBehind = actualTime - targetTimeAtPoint
            
            // Check if finished (within 25m of end coordinates or snapped to last coordinate)
            let distToEnd = SegmentMatcher.haversineDistance(
                lat1: latitude, lon1: longitude,
                lat2: segment.endLatitude, lon2: segment.endLongitude
            )
            
            if closestIdx == coords.count - 1 || distToEnd <= 25.0 {
                segmentCompleted = true
                isInsideSegment = false
                
                // Add new segment effort to SwiftData database
                let newEffort = SegmentEffort(
                    activityId: 99999, // Simulated/Live active session
                    activityName: "Живое ведение по сегменту",
                    athleteName: "Вы",
                    startDate: Date(),
                    elapsedTime: actualTime,
                    averageHeartRate: 165.0,
                    averagePower: isCycling ? 240.0 : nil,
                    averageSpeed: segment.distanceMeters / actualTime,
                    isMock: false
                )
                newEffort.segment = segment
                context.insert(newEffort)
                segment.efforts.append(newEffort)
                try? context.save()
                
                HapticManager.success()
                print("[LiveSegment] Completed segment: \(segment.name) in \(actualTime)s")
                
                // Show completion banner for 4 seconds, then close overlay
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    self.activeSegment = nil
                    self.segmentCompleted = false
                }
            }
        }
    }
}
