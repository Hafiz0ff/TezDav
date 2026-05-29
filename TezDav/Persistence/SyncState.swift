import Foundation
import SwiftData

@Model
final class SyncState {
    @Attribute(.unique) var key: String
    var lastSuccessfulSync: Date?
    var lastActivityStartDate: Date?
    var importedActivityCount: Int
    var lastErrorMessage: String?

    init(
        key: String = "strava",
        lastSuccessfulSync: Date? = nil,
        lastActivityStartDate: Date? = nil,
        importedActivityCount: Int = 0,
        lastErrorMessage: String? = nil
    ) {
        self.key = key
        self.lastSuccessfulSync = lastSuccessfulSync
        self.lastActivityStartDate = lastActivityStartDate
        self.importedActivityCount = importedActivityCount
        self.lastErrorMessage = lastErrorMessage
    }
}
