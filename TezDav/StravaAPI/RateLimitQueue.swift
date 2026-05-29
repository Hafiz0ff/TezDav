import Foundation

struct RateLimitBudget: Equatable, Sendable {
    var shortWindowRemaining: Int
    var dailyRemaining: Int
    var resetsAt: Date
}

actor RateLimitQueue {
    private var budget: RateLimitBudget

    init(budget: RateLimitBudget = RateLimitBudget(shortWindowRemaining: 200, dailyRemaining: 2_000, resetsAt: .now)) {
        self.budget = budget
    }

    func update(_ budget: RateLimitBudget) {
        self.budget = budget
    }

    func delayBeforeNextRequest(now: Date = .now) -> TimeInterval {
        guard budget.shortWindowRemaining > 0, budget.dailyRemaining > 0 else {
            return max(0, budget.resetsAt.timeIntervalSince(now))
        }
        return 0
    }

    func recordRequest(now: Date = .now) -> TimeInterval {
        let delay = delayBeforeNextRequest(now: now)
        guard delay == 0 else {
            return delay
        }
        budget.shortWindowRemaining = max(0, budget.shortWindowRemaining - 1)
        budget.dailyRemaining = max(0, budget.dailyRemaining - 1)
        return 0
    }
}
