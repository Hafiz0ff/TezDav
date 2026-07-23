# TezDav Handoff

Updated: 2026-07-23

## Current Product State

TezDav is local-first. Apple Health is the primary workout source on iOS; Supabase
and a custom server are not required. Workouts recorded by Apple Fitness/Workout or
another app that writes to HealthKit can be imported into local SwiftData storage.
Strava remains an optional future source.

The current iPhone development install uses bundle identifier
`com.hafizov.tezdav.local` because the available Personal Team profile cannot sign
the repository's App Group capability. This does not change the source project
bundle identifier or production signing configuration.

The source project no longer declares iCloud/CloudKit because persistence is local.
It still declares the App Group used by Live Activity. The temporary Personal Team
device build strips that App Group from both targets and keeps HealthKit plus
HealthKit background delivery.

## Data Flow

1. `HealthKitManager` requests access to workouts, routes, recovery data, and
   supported workout quantities.
2. `HealthKitWorkoutImporter` queries all `HKWorkout` records and associated data.
3. Imported activities and second-level samples are stored in SwiftData.
4. Existing metric engines calculate load, records, segments, and route matches.
5. Dashboard and Profile trigger initial, manual, and observer-driven refreshes.

## Language

`AppLanguage.isRussian` currently makes Russian the explicit product language and
injects `ru_RU` into the SwiftUI environment. `AppLanguage.sportName(_:)` translates
source sport identifiers without modifying user-entered activity names. A future
language selector should replace this static setting with String Catalog resources;
it must not infer language from metric/imperial units.

## Maps

All map-backed screens use `TezDavMapView`, a native MapKit wrapper. It draws workout
routes, pace-colored segments, route-builder waypoints, start/finish markers, and
heatmap tracks. The Google Maps SDK and fake API key were removed. With no route
content, the map requests the current device location and otherwise falls back to a
neutral world view.

## Key Files

- `TezDav/TrainingMetrics/HealthKitManager.swift`
- `TezDav/Sync/HealthKitWorkoutImporter.swift`
- `TezDav/Persistence/Activity.swift`
- `TezDav/Dashboard/OnboardingView.swift`
- `TezDav/Dashboard/DashboardView.swift`
- `TezDav/Dashboard/ProfileView.swift`
- `TezDav/Dashboard/ActivityDetailView.swift`
- `TezDav/Localization/AppLanguage.swift`
- `TezDav/Components/TezDavMapView.swift`
- `TezDav/RouteBuilder/RouteListView.swift`
- `TezDav/RouteBuilder/RouteBuilderView.swift`
- `TezDav/TezDav.entitlements`
- `TezDav/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png`

## Build And Test

```sh
xcodebuild \
  -project TezDav.xcodeproj \
  -scheme TezDav \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TezDavDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -project TezDav.xcodeproj \
  -scheme TezDav \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  -parallel-testing-enabled NO \
  -only-testing:TezDavTests/IntegrationTests \
  test

cd Android
npm run verify
```

The Android verification currently passes TypeScript compilation, 13 unit tests,
and all 20 Expo Doctor checks. `npm audit --omit=dev` still reports moderate
transitive Expo/Xcode tooling findings; its proposed fix is an incompatible Expo
downgrade and was intentionally not applied.

## Strava Configuration

No client secret is committed. To re-enable Strava later, rotate the secret first
and provide `STRAVA_CLIENT_SECRET` as a local Xcode build setting. Keep
`STRAVA_CLIENT_ID` and `STRAVA_REDIRECT_URI` in `Info.plist`; tokens continue to use
the Keychain implementation.

## Next Validation

1. On the installed iPhone app, grant the requested Health permissions.
2. Run the Apple Health import and compare the latest workout duration, distance,
   heart rate, and route with Fitness.
3. Open Map and Route Builder and confirm that an empty map centers on the current
   location, the empty-state overlay is compact, and tapping the visible MapKit map
   adds route points.
4. Complete a short new workout and verify it appears automatically or on the next
   app launch.
5. For production distribution, sign with the intended Apple Developer team and
   verify HealthKit Background Delivery and App Groups. Do not re-enable iCloud
   unless the local-only product requirement changes.
