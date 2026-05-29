import XCTest
@testable import TezDav

final class TezDavTests: XCTestCase {
    func testAppModelContainerIsCreated() {
        XCTAssertNotNil(TezDavApp.modelContainer)
    }
}
