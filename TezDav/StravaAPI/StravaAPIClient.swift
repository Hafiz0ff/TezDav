import Foundation

protocol StravaAPIClientProtocol: Sendable {
    func activities(page: Int, perPage: Int, after: Date?) async throws -> [StravaActivitySummary]
    func streams(activityId: Int64) async throws -> StravaStreamSet?
    func athlete() async throws -> StravaAthlete
}

enum StravaAPIError: Error {
    case missingAccessToken
    case invalidURL
    case badStatus(Int)
}

struct StravaAPIClient: StravaAPIClientProtocol {
    let session: StravaSession
    let urlSession: URLSession
    let rateLimitQueue: RateLimitQueue
    private let decoder: JSONDecoder

    init(session: StravaSession, urlSession: URLSession = .shared, rateLimitQueue: RateLimitQueue = RateLimitQueue()) {
        self.session = session
        self.urlSession = urlSession
        self.rateLimitQueue = rateLimitQueue
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func athlete() async throws -> StravaAthlete {
        return try await get(path: "/api/v3/athlete", queryItems: [])
    }

    func activities(page: Int, perPage: Int = 100, after: Date? = nil) async throws -> [StravaActivitySummary] {

        var items = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        if let after {
            items.append(URLQueryItem(name: "after", value: String(Int(after.timeIntervalSince1970))))
        }
        return try await get(path: "/api/v3/athlete/activities", queryItems: items)
    }

    func streams(activityId: Int64) async throws -> StravaStreamSet? {
        let items = [
            URLQueryItem(name: "keys", value: "time,distance,latlng,heartrate,cadence,watts,velocity_smooth,altitude"),
            URLQueryItem(name: "key_by_type", value: "true")
        ]
        return try await get(path: "/api/v3/activities/\(activityId)/streams", queryItems: items)
    }

    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        let delay = await rateLimitQueue.recordRequest()
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        guard let accessToken = try await session.validAccessToken() else {
            throw StravaAPIError.missingAccessToken
        }

        var components = URLComponents(string: "https://www.strava.com\(path)")
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw StravaAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw StravaAPIError.badStatus(http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }
}
