import Foundation
import SwiftData

@Model
final class FriendActivity {
    @Attribute(.unique) var id: UUID
    var friendName: String
    var friendAvatar: String // Initial letters or SF symbol name, e.g. "DK"
    var sportType: String // "Run", "Ride", "Walk", "Swim"
    var title: String
    var distanceMeters: Double
    var durationSeconds: Double
    var startDate: Date
    var encodedPolyline: String?
    var kudosCount: Int
    var hasKudosByMe: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \FriendComment.friendActivity)
    var comments: [FriendComment] = []
    
    init(
        id: UUID = UUID(),
        friendName: String,
        friendAvatar: String,
        sportType: String,
        title: String,
        distanceMeters: Double,
        durationSeconds: Double,
        startDate: Date = Date(),
        encodedPolyline: String? = nil,
        kudosCount: Int = 0,
        hasKudosByMe: Bool = false
    ) {
        self.id = id
        self.friendName = friendName
        self.friendAvatar = friendAvatar
        self.sportType = sportType
        self.title = title
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.startDate = startDate
        self.encodedPolyline = encodedPolyline
        self.kudosCount = kudosCount
        self.hasKudosByMe = hasKudosByMe
    }
}
