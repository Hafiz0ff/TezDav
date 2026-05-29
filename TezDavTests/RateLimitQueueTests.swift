import XCTest
@testable import TezDav

final class RateLimitQueueTests: XCTestCase {
    func testQueueAllowsRequestsUnderBudget() async {
        let now = Date(timeIntervalSince1970: 0)
        let queue = RateLimitQueue(budget: RateLimitBudget(shortWindowRemaining: 2, dailyRemaining: 2, resetsAt: now.addingTimeInterval(900)))

        let delay = await queue.recordRequest(now: now)
        let nextDelay = await queue.delayBeforeNextRequest(now: now)

        XCTAssertEqual(delay, 0)
        XCTAssertEqual(nextDelay, 0)
    }

    func testQueueDelaysWhenBudgetIsExhausted() async {
        let now = Date(timeIntervalSince1970: 0)
        let queue = RateLimitQueue(budget: RateLimitBudget(shortWindowRemaining: 0, dailyRemaining: 10, resetsAt: now.addingTimeInterval(900)))

        let delay = await queue.recordRequest(now: now)

        XCTAssertEqual(delay, 900)
    }
}
