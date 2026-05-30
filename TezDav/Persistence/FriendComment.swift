import Foundation
import SwiftData

@Model
final class FriendComment {
    @Attribute(.unique) var id: UUID
    var authorName: String
    var text: String
    var createdAt: Date
    
    var friendActivity: FriendActivity?
    
    init(id: UUID = UUID(), authorName: String, text: String, createdAt: Date = Date()) {
        self.id = id
        self.authorName = authorName
        self.text = text
        self.createdAt = createdAt
    }
}
