import XCTest
import SwiftData
import CoreLocation
@testable import TezDav

@MainActor
final class SocialFeedTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUpWithError() throws {
        let schema = Schema([FriendActivity.self, FriendComment.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
    }
    
    // Test 1: Insertion and Retrieval
    func testFriendActivityInsertionAndFetch() throws {
        let activity = FriendActivity(
            friendName: "Далер К.",
            friendAvatar: "ДК",
            sportType: "Ride",
            title: "Варзобское ущелье",
            distanceMeters: 34200.0,
            durationSeconds: 6300.0,
            startDate: Date(),
            encodedPolyline: "abc",
            kudosCount: 5,
            hasKudosByMe: false
        )
        
        context.insert(activity)
        try context.save()
        
        let descriptor = FetchDescriptor<FriendActivity>()
        let results = try context.fetch(descriptor)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.friendName, "Далер К.")
        XCTAssertEqual(results.first?.title, "Варзобское ущелье")
        XCTAssertEqual(results.first?.distanceMeters, 34200.0)
    }
    
    // Test 2: Kudos Toggling Logic
    func testKudosToggling() throws {
        let activity = FriendActivity(
            friendName: "Мария С.",
            friendAvatar: "МС",
            sportType: "Run",
            title: "Пробежка",
            distanceMeters: 5000,
            durationSeconds: 1500,
            kudosCount: 10,
            hasKudosByMe: false
        )
        
        context.insert(activity)
        try context.save()
        
        // Toggle Kudos On
        activity.kudosCount += 1
        activity.hasKudosByMe = true
        try context.save()
        
        XCTAssertEqual(activity.kudosCount, 11)
        XCTAssertTrue(activity.hasKudosByMe)
        
        // Toggle Kudos Off
        activity.kudosCount -= 1
        activity.hasKudosByMe = false
        try context.save()
        
        XCTAssertEqual(activity.kudosCount, 10)
        XCTAssertFalse(activity.hasKudosByMe)
    }
    
    // Test 3: Comment Association
    func testCommentAssociation() throws {
        let activity = FriendActivity(
            friendName: "Алекс М.",
            friendAvatar: "АМ",
            sportType: "Walk",
            title: "Прогулка",
            distanceMeters: 3000,
            durationSeconds: 1800
        )
        context.insert(activity)
        
        let comment = FriendComment(authorName: "Мария С.", text: "Отлично погулял!")
        activity.comments.append(comment)
        context.insert(comment)
        
        try context.save()
        
        let activityDescriptor = FetchDescriptor<FriendActivity>()
        let activities = try context.fetch(activityDescriptor)
        
        XCTAssertEqual(activities.first?.comments.count, 1)
        XCTAssertEqual(activities.first?.comments.first?.text, "Отлично погулял!")
        XCTAssertEqual(activities.first?.comments.first?.authorName, "Мария С.")
    }
    
    // Test 4: Database Seeding Logic
    func testDatabaseSeeding() throws {
        // Run seed method
        SyncService.seedFriendActivitiesIfNeeded(context: context)
        
        let activityDescriptor = FetchDescriptor<FriendActivity>()
        let activities = try context.fetch(activityDescriptor)
        
        // Should seed Daler, Maria, Alex = 3 activities
        XCTAssertEqual(activities.count, 3, "Seeding must populate exactly 3 activities")
        
        let daler = activities.first(where: { $0.friendName == "Далер К." })
        XCTAssertNotNil(daler)
        XCTAssertEqual(daler?.comments.count, 2, "Daler activity should have 2 comments seeded")
        
        let maria = activities.first(where: { $0.friendName == "Мария С." })
        XCTAssertNotNil(maria)
        XCTAssertEqual(maria?.comments.count, 1, "Maria activity should have 1 comment seeded")
    }
}
