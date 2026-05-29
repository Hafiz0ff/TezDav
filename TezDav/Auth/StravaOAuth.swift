import Foundation

enum StravaOAuthError: Error, Equatable {
    case invalidAuthorizationURL
    case missingCode
}

enum StravaOAuth {
    static let scopes = ["activity:read_all", "profile:read_all"]

    static func authorizationURL(config: StravaConfig, state: String) throws -> URL {
        var components = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: ",")),
            URLQueryItem(name: "state", value: state)
        ]

        guard let url = components?.url else {
            throw StravaOAuthError.invalidAuthorizationURL
        }
        return url
    }

    static func authorizationCode(from callbackURL: URL) throws -> String {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
        guard let code = items?.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw StravaOAuthError.missingCode
        }
        return code
    }
}
