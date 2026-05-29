import XCTest
@testable import TezDav

final class StravaOAuthTests: XCTestCase {
    func testAuthorizationURLContainsRequiredScopesAndRedirectURI() throws {
        let config = StravaConfig(
            clientId: "123",
            clientSecret: "secret",
            redirectScheme: "tezdav",
            redirectURI: "tezdav://auth/callback"
        )

        let url = try StravaOAuth.authorizationURL(config: config, state: "abc")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(items["client_id"], "123")
        XCTAssertEqual(items["redirect_uri"], "tezdav://auth/callback")
        XCTAssertEqual(items["scope"], "activity:read_all,profile:read_all")
        XCTAssertEqual(items["state"], "abc")
    }

    func testAuthorizationCodeIsReadFromCallbackURL() throws {
        let code = try StravaOAuth.authorizationCode(from: URL(string: "tezdav://auth/callback?code=run123")!)

        XCTAssertEqual(code, "run123")
    }

    func testSessionRefreshesExpiringToken() async throws {
        let store = InMemoryTokenStore()
        try store.saveToken(StravaToken(
            accessToken: "old",
            refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 100)
        ))
        let refresher = MockTokenRefresher(token: StravaToken(
            accessToken: "new",
            refreshToken: "refresh2",
            expiresAt: Date(timeIntervalSince1970: 10_000)
        ))
        let session = StravaSession(tokenStore: store, refresher: refresher)

        let accessToken = try await session.validAccessToken(now: Date(timeIntervalSince1970: 90))

        XCTAssertEqual(accessToken, "new")
        XCTAssertEqual(try store.loadToken()?.accessToken, "new")
    }
}

private struct MockTokenRefresher: StravaTokenRefreshing {
    let token: StravaToken

    func refreshToken(_ refreshToken: String) async throws -> StravaToken {
        token
    }
}
