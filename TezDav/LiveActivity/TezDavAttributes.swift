import ActivityKit
import Foundation

struct TezDavAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Sync progress state
        var loadedCount: Int
        var totalCount: Int
        var isSyncing: Bool
        
        // Post-workout summary state
        var workoutName: String?
        var sportType: String?
        var distanceMeters: Double?
        var durationSeconds: Double?
        var trainingLoad: Double?
    }
    
    // Static fields
    var title: String
}
