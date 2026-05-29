# TezDav iOS Foundation Design

## Scope

This first increment builds a working native iOS 17 SwiftUI application named TezDav. It focuses on the vertical slice needed to connect Strava data to local analytics:

- App shell and navigation.
- Local SwiftData persistence.
- Keychain-backed token storage.
- Strava OAuth/session infrastructure.
- Rate-limited Strava API client.
- Import/sync service for historical and new activities.
- Training load calculations for TRIMP, TSS-like load, CTL, ATL, and TSB.
- Dashboard reading local data.

Maps, detailed activity charts, personal records, VO2max, and long-form reports are intentionally left for later increments.

## Architecture

The app is split by responsibility:

- `TezDavApp` owns SwiftUI startup and the SwiftData model container.
- `AppRootView` switches between unauthenticated onboarding and the main dashboard.
- `Auth` builds OAuth URLs, exchanges authorization codes, refreshes tokens, and stores credentials in Keychain.
- `StravaAPI` contains endpoint DTOs and a request queue that respects Strava limits.
- `Persistence` contains SwiftData models for activities, streams, sync state, and user settings.
- `Sync` coordinates initial and incremental imports and exposes progress state to SwiftUI.
- `TrainingMetrics` contains pure calculation code for load and fitness/fatigue/form.
- `Dashboard` renders current analytics from local data.

The app has no backend, no cloud sync, no analytics SDKs, and no third-party tracking.

## Data Flow

On first launch, the user taps Connect Strava. The app opens the Strava OAuth URL with scopes `activity:read_all` and `profile:read_all`. The callback returns an authorization code, which is exchanged for access and refresh tokens. The refresh token is stored in Keychain.

After authentication, `SyncService` fetches activities page by page, fetches details/streams where needed, calculates training metrics, and writes normalized records to SwiftData. Dashboard queries local SwiftData only, so it can render quickly and offline.

On later launches, the session manager refreshes the access token if needed, then sync pulls activities updated since the last successful sync.

## Error Handling

OAuth failures return a visible authentication error and keep the user on onboarding.

Network and Strava API failures are represented as typed errors. The sync service records progress and failure messages without deleting existing local data.

Rate limits are handled through a request queue. When the short-window or daily budget is exhausted, requests wait instead of failing immediately.

## Configuration

The app expects Strava configuration values:

- `STRAVA_CLIENT_ID`
- `STRAVA_CLIENT_SECRET`
- `STRAVA_REDIRECT_SCHEME`

The first code increment includes a checked-in sample config and runtime validation. Real credentials must not be committed.

## Testing

Pure metric calculations are covered with unit tests. OAuth URL construction, token refresh decisions, and rate-limit scheduling are testable without the network. Sync orchestration uses mock API/client protocols so imported activities can be verified deterministically.

The initial build target must compile in Xcode with iOS 17+.
