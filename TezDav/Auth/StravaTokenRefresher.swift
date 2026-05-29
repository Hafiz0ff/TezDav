import Foundation

final class StravaTokenRefresher: StravaTokenRefreshing, Sendable {
    private let config: StravaConfig
    private let urlSession: URLSession

    init(config: StravaConfig, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func refreshToken(_ refreshToken: String) async throws -> StravaToken {
        try await performTokenRequest(params: [
            "client_id": config.clientId,
            "client_secret": config.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ])
    }

    func exchangeCode(_ code: String) async throws -> StravaToken {
        try await performTokenRequest(params: [
            "client_id": config.clientId,
            "client_secret": config.clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ])
    }

    private func performTokenRequest(params: [String: String]) async throws -> StravaToken {
        let components = URLComponents(string: "https://www.strava.com/oauth/token")
        
        guard let url = components?.url else {
            throw StravaAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var queryItems: [URLQueryItem] = []
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        var urlComponents = URLComponents()
        urlComponents.queryItems = queryItems
        request.httpBody = urlComponents.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StravaAPIError.badStatus(0)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw StravaAPIError.badStatus(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
        return tokenResponse.token
    }
}
