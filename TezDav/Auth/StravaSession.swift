import Foundation

struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }

    var token: StravaToken {
        StravaToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(expiresAt))
        )
    }
}

protocol StravaTokenRefreshing: Sendable {
    func refreshToken(_ refreshToken: String) async throws -> StravaToken
}

struct StravaSession: Sendable {
    let tokenStore: TokenStore
    let refresher: StravaTokenRefreshing

    func validAccessToken(now: Date = .now) async throws -> String? {
        guard let token = try tokenStore.loadToken() else {
            return nil
        }
        if token.requiresRefresh(now: now) {
            let refreshed = try await refresher.refreshToken(token.refreshToken)
            try tokenStore.saveToken(refreshed)
            return refreshed.accessToken
        }
        return token.accessToken
    }
}
