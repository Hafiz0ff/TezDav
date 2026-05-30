import Foundation
import SwiftData

@Model
final class Achievement {
    @Attribute(.unique) var id: UUID
    var type: String                  // e.g. "run_5k", "streak_7d", "steps_10k"
    var dateEarned: Date
    var associatedActivityId: Int64?  // reference to activity that unlocked it (optional)
    var title: String
    var descriptionText: String

    init(
        id: UUID = UUID(),
        type: String,
        dateEarned: Date = Date(),
        associatedActivityId: Int64? = nil,
        title: String,
        descriptionText: String
    ) {
        self.id = id
        self.type = type
        self.dateEarned = dateEarned
        self.associatedActivityId = associatedActivityId
        self.title = title
        self.descriptionText = descriptionText
    }
}
