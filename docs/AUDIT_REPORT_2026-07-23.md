# TezDav iOS Audit Report

Date: 2026-07-23

## Scope

- iOS 17+ SwiftUI application startup and navigation.
- HealthKit authorization, workout discovery, route and metric import.
- SwiftData persistence and duplicate handling.
- Dashboard/Profile synchronization entry points.
- Strava fallback configuration and secret handling.
- Russian UI copy, accessibility labels, and App Shortcuts.
- Map rendering, camera defaults, and route-builder interaction.
- App icon packaging.
- Simulator tests and a signed build on a connected iPhone 16 Pro Max.
- Android dependency compatibility, type checking, tests, and Expo diagnostics.

## Findings Fixed

### HealthKit was not a complete workout source

The app previously read recovery telemetry but did not build local `Activity` records
from workouts saved by Apple Fitness or third-party apps. `HealthKitWorkoutImporter`
now imports the full workout history, supported quantity samples, and route locations
into SwiftData. Imported activities are enriched with records, segments, route
matching, and recalculated training load.

### A denied route permission could discard a valid workout

HealthKit can authorize workout summaries while withholding route data. Route reads
are now best-effort: a denied or unavailable route no longer prevents the workout,
heart rate, distance, power, cadence, or other available metrics from being saved.

### Duplicate HealthKit identifiers could crash an import

Constructing the UUID lookup with `Dictionary(uniqueKeysWithValues:)` could trap if a
previous database state contained duplicate identifiers. Lookup construction now
keeps the first existing record and continues safely.

### Background delivery was requested without its entitlement

The app called `enableBackgroundDelivery` but the target lacked
`com.apple.developer.healthkit.background-delivery`. The entitlement is now declared,
and an `HKObserverQuery` notifies the active dashboard when workouts change.

### Startup still treated Strava as the primary source

Onboarding, dashboard empty state, pull-to-refresh, and profile synchronization now
use Apple Health first. Strava remains optional and no login/password form is shown
on startup.

### HealthKit activities could trigger unnecessary Strava requests

Activity details now request remote streams only for records whose source is
`strava`. HealthKit records use their locally imported samples.

### A Strava client secret was stored in the tracked plist

`Info.plist` now references the `STRAVA_CLIENT_SECRET` build setting instead of
containing a secret. Strava is disabled when that setting is empty.

### Unused server purchase code contradicted local-first operation

The unused iOS backend receipt client and purchase manager were removed from the
Xcode target. TezDav does not need Supabase or another server to import and analyze
Apple Health workouts.

### The local app still declared CloudKit capabilities

SwiftData is configured with `cloudKitDatabase: .none`, but the app entitlement file
still declared iCloud containers and CloudKit. Those unused capabilities were
removed. The App Group remains because it is used by the Live Activity extension.

### The Russian UI depended on the device locale and measurement system

Several screens selected English copy from `Locale.current`, while one planner
selected its language using the metric/imperial preference. This produced the mixed
Russian-English interface visible on the device. Russian is now the explicit app
language, date and number formatting use `ru_RU`, sport names are translated
centrally, and visible copy, accessibility labels, import errors, and App Shortcut
phrases were corrected. Sports-science abbreviations such as CTL, ATL, TSB, TSS, and
TRIMP remain unchanged intentionally.

### The iOS icon did not match the prepared cross-platform icon

The iOS AppIcon asset now uses the prepared 1024 x 1024 TezDav neon `TJ` artwork from
the Android project. Asset compilation produced the expected device icon variants.

### Maps depended on a nonfunctional Google Maps key

The route builder and several route previews used Google Maps with a deliberately
fake API key. This rendered local markers over an empty surface. The shared map
component now uses native MapKit, the Google Maps package and fake key were removed,
and route lines, colored segments, heatmap tracks, markers, map styles, taps, and
viewport fitting were preserved. Empty maps request the user's current location; if
it is unavailable, they use a neutral automatic/world fallback instead of a
hardcoded city.

### The empty route overlay occupied too much of the map

The generic empty state included large icon, spacing, and bottom padding inside its
background. The Map tab now uses a dedicated compact overlay with a shorter message
and the same route creation action.

### Android dependencies did not match Expo SDK 57

`expo`, `expo-build-properties`, and `react-native-screens` were behind the versions
required by the installed Expo SDK. The packages and lockfile are now aligned, and
all Expo Doctor checks pass.

## Verification

- iOS simulator build: passed.
- `IntegrationTests`: 10 passed, 0 failed.
- `SnapshotTests`: 9 test methods and 54 visual variants passed.
- Signed `arm64` device build: passed.
- Install on connected iPhone 16 Pro Max: passed.
- Launch and post-launch process check on the iPhone: passed.
- App icon input: 1024 x 1024 PNG, no alpha channel.
- Android TypeScript check: passed.
- Android unit tests: 13 passed, 0 failed.
- Android Expo Doctor: 20 checks passed.

## Residual Risk

`npm audit --omit=dev` reports moderate findings in the transitive Expo/Xcode build
tooling chain. The available automatic remediation would downgrade Expo across a
major compatibility boundary, so it was not applied. There are no high or critical
findings, and the runtime dependency set passes Expo Doctor.

## Remaining Manual Checks

- Accept any newly displayed Apple Health permissions on the iPhone.
- Confirm that a recent Apple Workout appears with its route and heart-rate stream.
- Record one new workout and verify background/next-launch synchronization.
- Configure the production signing team and the original bundle capabilities before
  App Store or TestFlight distribution.
