import Foundation

struct StravaConfig: Equatable, Sendable {
    let clientId: String
    let clientSecret: String
    let redirectScheme: String
    let redirectURI: String

    var isConfigured: Bool {
        !clientId.isEmpty && !clientSecret.isEmpty && !redirectScheme.isEmpty && !redirectURI.isEmpty
    }

    static func fromBundle(_ bundle: Bundle = .main) -> StravaConfig {
        StravaConfig(
            clientId: bundle.object(forInfoDictionaryKey: "STRAVA_CLIENT_ID") as? String ?? "",
            clientSecret: bundle.object(forInfoDictionaryKey: "STRAVA_CLIENT_SECRET") as? String ?? "",
            redirectScheme: bundle.object(forInfoDictionaryKey: "STRAVA_REDIRECT_SCHEME") as? String ?? "tezdav",
            redirectURI: bundle.object(forInfoDictionaryKey: "STRAVA_REDIRECT_URI") as? String ?? "tezdav://auth/callback"
        )
    }
}
