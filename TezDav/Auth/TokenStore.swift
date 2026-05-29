import Foundation

struct StravaToken: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    func requiresRefresh(now: Date = .now, leeway: TimeInterval = 300) -> Bool {
        expiresAt.timeIntervalSince(now) <= leeway
    }
}

protocol TokenStore: Sendable {
    func loadToken() throws -> StravaToken?
    func saveToken(_ token: StravaToken) throws
    func clearToken() throws
}

enum TokenStoreError: Error {
    case encodeFailed
    case decodeFailed
    case keychain(OSStatus)
}

final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private var token: StravaToken?

    func loadToken() throws -> StravaToken? {
        token
    }

    func saveToken(_ token: StravaToken) throws {
        self.token = token
    }

    func clearToken() throws {
        token = nil
    }
}
